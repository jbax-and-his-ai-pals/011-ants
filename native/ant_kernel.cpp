// Hot loops for the existing simulation. No worker aggregation or skipped ticks.
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <cmath>
#include <vector>
#include <cstring>

using namespace godot;
namespace {
constexpr int COLS=234, ROWS=126, CELLS=COLS*ROWS, BC=103, BR=56, BCS=BC*BR;
constexpr double PI=3.14159265358979323846, STEP=1.0/30.0;
int cell(Vector2 p) {
    return std::clamp(int(double(p.y)/14.0),0,ROWS-1)*COLS + std::clamp(int(double(p.x)/14.0),0,COLS-1);
}
struct Patch { Vector2 pos; int64_t amount; Dictionary original; bool changed=false; int resource=0; int layer=-1; };
bool avoided(Vector2 point,const Vector2 *zones,int count) {
    for(int k=0;k<count;++k) if(point.distance_squared_to(zones[k])<100.0f*100.0f) return true;
    return false;
}
Vector2 avoid_direction(Vector2 point,Vector2 goal,int worker,const Vector2 *zones,int count) {
    Vector2 escape; bool inside=false;
    for(int k=0;k<count;++k) {
        Vector2 outward=point-zones[k]; float distance=outward.length();
        if(distance<118) { inside=true; escape+=distance>0.01f?outward.normalized():Vector2::from_angle(float(worker*2.39996)); }
    }
    if(inside) return escape.length_squared()>0.01f?escape.normalized():Vector2::from_angle(float(worker*2.39996));
    Vector2 delta=goal-point; float length=delta.length();
    if(length<0.01f) return Vector2();
    Vector2 direction=delta/length, result; double nearest=INFINITY;
    for(int k=0;k<count;++k) {
        Vector2 toward=zones[k]-point; double along=toward.dot(direction);
        if(along<=0 || along>length+118 || along>=nearest) continue;
        if((toward-direction*float(along)).length_squared()>=118.0f*118.0f) continue;
        nearest=along; double cross=delta.cross(toward);
        double side=std::abs(cross)>0.001?(cross>0?-1.0:1.0):(worker%2?-1.0:1.0);
        double angle=double(toward.angle())+side*std::asin(std::min(1.0,118.0/double(toward.length())));
        result=Vector2::from_angle(float(angle));
    }
    return result;
}
Vector2 safe_step(Vector2 old,Vector2 proposed,const Vector2 *zones,int count) {
    for(int k=0;k<count;++k) if(old.distance_squared_to(zones[k])>=10000 && proposed.distance_squared_to(zones[k])<10000) return old;
    return proposed;
}
}

class AntKernel : public RefCounted {
    GDCLASS(AntKernel, RefCounted)
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("trail_pixels","simulation"), &AntKernel::trail_pixels);
        ClassDB::bind_method(D_METHOD("minimap_batch","simulation","layer","origin","size"), &AntKernel::minimap_batch);
        ClassDB::bind_method(D_METHOD("remains_batch","simulation","layer","visible"), &AntKernel::remains_batch);
        ClassDB::bind_method(D_METHOD("living_count","simulation","colony"), &AntKernel::living_count);
        ClassDB::bind_method(D_METHOD("invaders_in","simulation","nest"), &AntKernel::invaders_in);
        ClassDB::bind_method(D_METHOD("decay_scent","simulation"), &AntKernel::decay_scent);
        ClassDB::bind_method(D_METHOD("visual_batch","simulation","visible","layer","zoom"), &AntKernel::visual_batch);
        ClassDB::bind_method(D_METHOD("mission_workers","simulation","processed"), &AntKernel::mission_workers);
        ClassDB::bind_method(D_METHOD("resolve_tick","simulation"), &AntKernel::resolve_tick);
        ClassDB::bind_method(D_METHOD("forage_batch","simulation","dt"), &AntKernel::forage_batch);
        ClassDB::bind_method(D_METHOD("prepare_encounters","simulation","dt"), &AntKernel::prepare_encounters);
    }
public:
    PackedByteArray trail_pixels(Object *s) {
        PackedFloat32Array food=s->get("food_scent"),home=s->get("home_scent"),coral=s->get("rival_food_scent"),azure=s->get("third_food_scent");
        PackedFloat32Array protein=s->get("protein_scent"),coral_protein=s->get("rival_protein_scent"),azure_protein=s->get("third_protein_scent");
        PackedInt32Array active=s->get("active_scent");bool third=int(s->get("colony_count"))==3;
        PackedByteArray pixels;pixels.resize(CELLS*4);pixels.fill(255);auto out=pixels.ptrw();for(int j=0;j<CELLS;++j)out[j*4+3]=0;
        for(int k=0;k<active.size();++k){int j=active[k];
            Color color(0.38,0.7,0.85,std::min(double(home[j])*0.065,0.16));
            color=color.blend(Color(0.68,0.88,0.4,std::min(double(std::max(food[j],protein[j]))*0.115,0.48)));
            color=color.blend(Color(0.96,0.43,0.46,std::min(double(std::max(coral[j],coral_protein[j]))*0.115,0.48)));
            if(third)color=color.blend(Color(0.35,0.68,0.96,std::min(double(std::max(azure[j],azure_protein[j]))*0.115,0.48)));
            uint32_t rgba=color.to_rgba32();out[j*4]=rgba>>24;out[j*4+1]=rgba>>16;out[j*4+2]=rgba>>8;out[j*4+3]=rgba;
        }
        return pixels;
    }
    Dictionary minimap_batch(Object *s,int layer,Vector2 origin,Vector2 size) {
        PackedVector2Array positions=s->get("positions");PackedInt32Array layers=s->get("layers");
        PackedFloat32Array health=s->get("health");PackedByteArray colonies=s->get("colonies");
        PackedVector2Array points;PackedColorArray colors;
        Color tints[3]={Color::html("edb76c"),Color::html("ef907f"),Color::html("85bde5")};
        for(int i=0;i<health.size();++i)if(health[i]>0 && layers[i]==layer) {
            Vector2 point=origin+positions[i]/Vector2(3276,1764)*size;
            points.push_back(point-Vector2(0.6,0));points.push_back(point+Vector2(0.6,0));colors.push_back(tints[colonies[i]]);
        }
        Dictionary result;result["points"]=points;result["colors"]=colors;return result;
    }
    Dictionary remains_batch(Object *s,int layer,Rect2 visible) {
        Array remains=s->get("remains");PackedVector2Array points;PackedColorArray colors;
        Color tints[3]={Color::html("edb76c"),Color::html("ef907f"),Color::html("85bde5")};
        for(int i=0;i<remains.size();++i){
            Dictionary body=remains[i];Vector2 p=body["pos"];
            if(int(body["layer"])!=layer || !visible.has_point(p))continue;
            Color tint=tints[int(body["colony"])];tint.a=std::min(0.65,double(body["time"])/8.0);
            points.push_back(p-Vector2(3,3));points.push_back(p+Vector2(3,3));colors.push_back(tint);
            points.push_back(p+Vector2(-3,3));points.push_back(p+Vector2(3,-3));colors.push_back(tint);
        }
        Dictionary result;result["points"]=points;result["colors"]=colors;return result;
    }
    int living_count(Object *s,int colony) {
        PackedFloat32Array health=s->get("health"); PackedByteArray colonies=s->get("colonies");
        auto hp=health.ptr(); auto side=colonies.ptr(); int result=0;
        for(int i=0;i<health.size();++i) if(hp[i]>0 && side[i]==colony) ++result;
        return result;
    }
    int invaders_in(Object *s,int nest) {
        PackedFloat32Array health=s->get("health"); PackedByteArray colonies=s->get("colonies"); PackedInt32Array layers=s->get("layers");
        auto hp=health.ptr(); auto side=colonies.ptr(); auto layer=layers.ptr(); int result=0;
        for(int i=0;i<health.size();++i) if(hp[i]>0 && layer[i]==nest && side[i]!=nest) ++result;
        return result;
    }
    void decay_scent(Object *s) {
        PackedByteArray shade=s->get("surface_shade"); auto shaded=shade.ptr();
        const char *names[9]={"food_scent","home_scent","rival_food_scent","rival_home_scent","third_food_scent","third_home_scent","protein_scent","rival_protein_scent","third_protein_scent"};
        PackedFloat32Array fields[9]; float *data[9];
        for(int k=0;k<9;++k) {fields[k]=s->get(names[k]); data[k]=fields[k].ptrw();}
        PackedInt32Array active=s->get("active_scent"); PackedByteArray flags=s->get("scent_active");
        auto p=active.ptrw(); auto present=flags.ptrw(); int length=active.size();
        for(int slot=length-1;slot>=0;--slot) {
            int j=p[slot]; float peak=0;
            for(int k=0;k<9;++k) {data[k][j]*=shaded[j]?((k<6 && k%2)?0.99498743710662:0.9964938534682489):((k<6 && k%2)?0.99:0.993); peak=std::max(peak,data[k][j]);}
            if(peak<0.008f) {for(int k=0;k<9;++k)data[k][j]=0;present[j]=0;p[slot]=p[--length];Object *picture=s->get("trail_image");if(picture)picture->call("set_pixel",j%COLS,j/COLS,Color(0,0,0,0));}
        }
        active.resize(length);
        for(int k=0;k<9;++k)s->set(names[k],fields[k]);
        s->set("active_scent",active);s->set("scent_active",flags);s->set("trails_dirty",true);
    }
    PackedInt32Array mission_workers(Object *s,PackedByteArray processed) {
        Array workers=s->get("colony_workers"); int sides=s->get("colony_count"); int64_t tick=s->get("tick_number");
        PackedFloat32Array health=s->get("health"); PackedInt32Array result;
        for(int phase=0;phase<sides;++phase) {
            PackedInt32Array slots=workers[(tick+phase)%sides];
            for(int k=0;k<slots.size();++k){int i=slots[k];if(health[i]>0 && !processed[i])result.push_back(i);}
        }
        return result;
    }
    Dictionary visual_batch(Object *s,Rect2 visible,int layer,double zoom) {
        PackedFloat32Array health=s->get("health"),headings=s->get("headings"),flashes=s->get("hit_flashes");
        PackedByteArray castes=s->get("castes");
        PackedVector2Array positions=s->get("positions");PackedInt32Array layers=s->get("layers");
        PackedByteArray roles=s->get("roles"),colonies=s->get("colonies"),carrying=s->get("carrying"),cargo_kind=s->get("cargo_resource");
        int n=health.size(), counts[3]={0,0,0},shown=0;PackedFloat32Array buffers[3];float *data[3];
        for(int k=0;k<3;++k){buffers[k].resize(n*12);data[k]=buffers[k].ptrw();}
        auto emit=[&](int batch,int i,Color color){
            float *p=data[batch]+counts[batch]++*12;float scale=(batch!=2 && castes[i])?1.35f:1.0f;float c=std::cos(headings[i])*scale,a=std::sin(headings[i])*scale;
            p[0]=c;p[1]=-a;p[2]=0;p[3]=positions[i].x;p[4]=a;p[5]=c;p[6]=0;p[7]=positions[i].y;
            p[8]=color.r;p[9]=color.g;p[10]=color.b;p[11]=color.a;
        };
        Color tints[3]={Color::html("edb76c"),Color::html("ef907f"),Color::html("85bde5")};
        const Color forager_color=Color::html("f0dcab"), cargo_color=Color::html("bee27c"), protein_color=Color::html("c89c71");
        for(int i=0;i<n;++i)if(health[i]>0 && layers[i]==layer && visible.has_point(positions[i])) {
            Color tint=colonies[i]==0 && roles[i]==0?forager_color:tints[colonies[i]];
            if(flashes[i]>0)tint=Color(1,1,1);emit(zoom<0.65?1:0,i,tint);
            if(carrying[i])emit(2,i,cargo_kind[i]?protein_color:cargo_color);++shown;
        }
        Array result;for(int k=0;k<3;++k)result.push_back(buffers[k]);
        PackedInt32Array sizes;for(int k=0;k<3;++k)sizes.push_back(counts[k]);
        Dictionary output;output["buffers"]=result;output["counts"]=sizes;output["visible"]=shown;return output;
    }
    PackedInt32Array resolve_tick(Object *s) {
        PackedByteArray castes=s->get("castes");
        PackedFloat32Array hp=s->get("health"),cd=s->get("attack_cooldowns"),damage=s->get("combat_damage"),flashes=s->get("hit_flashes"),walk=s->get("walked");
        PackedInt32Array layers=s->get("layers"),snapshot_layers=s->get("layer_snapshot"),enemies=s->get("opponents"),attackers=s->get("last_attackers"),doctrines=s->get("doctrines");
        PackedVector2Array positions=s->get("positions"),snapshot=s->get("movement_snapshot");
        PackedByteArray roles=s->get("roles"),colonies=s->get("colonies");
        PackedFloat64Array queen_hp=s->get("queen_health"),queen_damage=s->get("queen_damage");Array randoms=s->get("ant_rng");
        auto health=hp.ptrw();auto cooldown=cd.ptrw();auto hits=damage.ptrw();auto flash=flashes.ptrw();auto walked=walk.ptrw();auto last=attackers.ptrw();auto qdamage=queen_damage.ptrw();
        bool combat=s->get("combat_enabled");PackedInt32Array dead;
        for(int i=0;i<hp.size();++i){
            if(health[i]<=0)continue;
            if(layers[i]==snapshot_layers[i])walked[i]+=positions[i].distance_to(snapshot[i]);
            if(!combat || cooldown[i]>0 || layers[i]!=snapshot_layers[i])continue;
            int other=enemies[i];double bonus=(doctrines[colonies[i]]==2 && (roles[i]==2 || roles[i]==3 || roles[i]==5)?1.05:1.0)*(castes[i]?1.5:1.0);
            if(other>=0 && layers[other]==layers[i] && positions[i].distance_squared_to(positions[other])<=144 && (layers[i]==-1 || bool(s->call("_tunnel_line_clear",positions[i],positions[other],layers[i])))) {
                auto rng=Object::cast_to<RandomNumberGenerator>(randoms[i]);hits[other]+=rng->randf_range(0.85,1.15)*bonus;last[other]=i;cooldown[i]=0.75;
            }else if(other<0 && roles[i]==2 && layers[i]>=0 && layers[i]!=colonies[i] && queen_hp[layers[i]]>0) {
                Vector2 queen=s->call("queen_position",layers[i]);
                if(positions[i].distance_squared_to(queen)<=18*18 && bool(s->call("_tunnel_line_clear",positions[i],queen,layers[i]))) {
                    auto rng=Object::cast_to<RandomNumberGenerator>(randoms[i]);qdamage[layers[i]]+=rng->randf_range(0.85,1.15)*bonus;cooldown[i]=0.75;
                }
            }
        }
        for(int i=0;i<hp.size();++i)if(health[i]>0 && hits[i]>0){health[i]=std::max(0.0f,health[i]-hits[i]);flash[i]=0.16;if(health[i]<=0)dead.push_back(i);}
        s->set("health",hp);s->set("attack_cooldowns",cd);s->set("combat_damage",damage);s->set("hit_flashes",flashes);s->set("walked",walk);s->set("last_attackers",attackers);s->set("queen_damage",queen_damage);return dead;
    }
    void prepare_encounters(Object *s, double dt) {
        PackedVector2Array positions=s->get("positions");
        PackedInt32Array layers=s->get("layers"), doctrines=s->get("doctrines");
        PackedByteArray colonies=s->get("colonies"), carrying=s->get("carrying"), roles=s->get("roles");
        PackedVector2Array goals=s->get("worker_order_goals"), avoid=s->get("avoid_points");
        auto zones=avoid.ptr(); int zone_count=avoid.size();
        PackedFloat32Array health=s->get("health"), cooldown=s->get("attack_cooldowns"), flashes=s->get("hit_flashes");
        int sides=int(s->get("colony_count")); int n=health.size();
        PackedInt32Array opponents, attackers; opponents.resize(n); attackers.resize(n);
        opponents.fill(-1); attackers.fill(-1);
        PackedFloat32Array damage; damage.resize(n); damage.fill(0);
        PackedFloat64Array queen_damage; queen_damage.resize(sides); queen_damage.fill(0);
        s->set("movement_snapshot",positions.duplicate()); s->set("layer_snapshot",layers.duplicate());
        auto p=positions.ptr(); auto layer=layers.ptr(); auto colony=colonies.ptr(); auto hp=health.ptr();
        auto cd=cooldown.ptrw(); auto flash=flashes.ptrw(); auto target=opponents.ptrw(); auto cargo=carrying.ptr();
        std::vector<int> heads(BCS*sides*(sides+1),-1), next(n,-1);
        for(int i=n-1;i>=0;--i) {
            if(cd[i]>0) cd[i]=std::max(0.0,double(cd[i])-dt);
            if(flash[i]>0) flash[i]=std::max(0.0,double(flash[i])-dt);
            if(hp[i]<=0) continue;
            int key=int(p[i].x/32.0f)+int(p[i].y/32.0f)*BC+((layer[i]+1)*sides+colony[i])*BCS;
            next[i]=heads[key]; heads[key]=i;
        }
        bool combat=s->get("combat_enabled");
        if(combat) for(int i=0;i<n;++i) {
            if(hp[i]<=0) continue;
            double radius=doctrines[colony[i]]==2 && (roles[i]==2 || roles[i]==3 || roles[i]==5)?34.0:30.0;
            if((doctrines[colony[i]]==1 && cargo[i]) || roles[i]==7) radius=12.0;
            double nearest=radius*radius;
            int cx=int(p[i].x/32.0f), cy=int(p[i].y/32.0f);
            for(int foe=0;foe<sides;++foe) {
            if(foe==colony[i]) continue;
            int base=((layer[i]+1)*sides+foe)*BCS;
            // Same bucket and slot tie order as the reference implementation.
            for(int y=std::max(0,cy-2);y<std::min(BR,cy+3);++y)
                for(int x=std::max(0,cx-2);x<std::min(BC,cx+3);++x)
                    for(int other=heads[x+y*BC+base];other>=0;other=next[other]) {
                        double distance=p[i].distance_squared_to(p[other]);
                        if(roles[i]==6 && distance>144) continue;
                        if(colony[i]==0 && layer[i]==-1 && distance>144) {
                            if(avoided(p[i],zones,zone_count) || avoided(p[other],zones,zone_count)) continue;
                        }
                        if(roles[i]==5 && distance>144 && p[other].distance_squared_to(goals[i])>110*110) continue;
                        if(distance<nearest && (layer[i]==-1 || bool(s->call("_tunnel_line_clear",p[i],p[other],layer[i])))) {
                            nearest=distance; target[i]=other;
                        }
                    }
            }
        }
        s->set("opponents",opponents); s->set("last_attackers",attackers); s->set("combat_damage",damage);
        s->set("queen_damage",queen_damage); s->set("attack_cooldowns",cooldown); s->set("hit_flashes",flashes);
    }

    PackedByteArray forage_batch(Object *s,double dt) {
        PackedFloat32Array maximum=s->get("max_health");
        PackedFloat64Array forage_multipliers=s->get("foraging_multipliers");
        PackedFloat32Array terrain_speed=s->get("surface_speed"); auto terrain=terrain_speed.ptr();
        PackedVector2Array positions=s->get("positions");
        PackedFloat32Array headings=s->get("headings"), trips=s->get("trips"), health=s->get("health");
        PackedByteArray carrying=s->get("carrying"), colonies=s->get("colonies"), roles=s->get("roles");
        PackedByteArray order_kinds=s->get("worker_order_kinds");
        PackedVector2Array order_goals=s->get("worker_order_goals"), avoid=s->get("avoid_points");
        auto zones=avoid.ptr(); int zone_count=avoid.size();
        PackedInt32Array layers=s->get("layers"), opponents=s->get("opponents"), deliveries=s->get("deliveries"), doctrines=s->get("doctrines");
        PackedFloat32Array food=s->get("food_scent"), home=s->get("home_scent"), rival_food=s->get("rival_food_scent"), rival_home=s->get("rival_home_scent"), third_food=s->get("third_food_scent"), third_home=s->get("third_home_scent");
        bool physical=s->get("chambers_enabled");
        PackedInt32Array inward=s->get("storage_flow"),outward=s->get("exit_flow"),entries=s->get("nest_entries"),capacity=s->get("storage_capacity"),ids=s->get("worker_ids");
        PackedInt32Array occupancy=s->get("tunnel_occupancy");
        if(physical)occupancy.fill(0);
        auto occupied=occupancy.ptrw();auto store_route=inward.ptr();auto exit_route=outward.ptr();auto entrances=entries.ptr();auto room_capacity=capacity.ptr();auto worker_id=ids.ptr();
        PackedFloat64Array stores=s->get("food_stores"), protein_stores=s->get("protein_stores"), weights=s->get("nutrition_weights");
        PackedByteArray cargo_kind=s->get("cargo_resource");
        PackedInt32Array resource_delivered=s->get("resource_delivered");
        PackedFloat32Array protein=s->get("protein_scent"), rival_protein=s->get("rival_protein_scent"), third_protein=s->get("third_protein_scent");
        PackedInt32Array active=s->get("active_scent"); PackedByteArray membership=s->get("scent_active");
        int sides=int(s->get("colony_count")); int n=health.size(); PackedByteArray processed; processed.resize(n); processed.fill(0);
        auto done=processed.ptrw(); auto p=positions.ptrw(); auto angle_data=headings.ptrw(); auto trip=trips.ptrw();
        auto hp=health.ptrw(); auto cargo=carrying.ptrw(); auto delivered=deliveries.ptrw(); auto bank=stores.ptrw();
        auto colony=colonies.ptr(); auto role=roles.ptr(); auto layer=layers.ptrw(); auto enemy=opponents.ptr();
        if(physical)for(int i=0;i<n;++i)if(hp[i]>0 && layer[i]>=0)++occupied[layer[i]*CELLS+cell(p[i])];
        auto present=membership.ptrw();
        auto kind=cargo_kind.ptrw(); auto protein_bank=protein_stores.ptrw(); auto resources=resource_delivered.ptrw(); auto demand=weights.ptr();
        float *fields[9]={food.ptrw(),home.ptrw(),rival_food.ptrw(),rival_home.ptrw(),third_food.ptrw(),third_home.ptrw(),protein.ptrw(),rival_protein.ptrw(),third_protein.ptrw()};
        std::vector<int> active_cells;
        if(active.size()) active_cells.assign(active.ptr(), active.ptr()+active.size());
        auto deposit=[&](float *field,Vector2 point,double strength) {
            int j=cell(point), x=j%COLS, y=j/COLS;
            auto add=[&](int k,double amount) {
                field[k]=std::min(5.0,double(field[k])+amount);
                if(!present[k]) { present[k]=1; active_cells.push_back(k); }
            };
            add(j,strength*STEP*9);
            double spread=strength*STEP*2.2;
            if(x>0) add(j-1,spread); if(x<COLS-1) add(j+1,spread);
            if(y>0) add(j-COLS,spread); if(y<ROWS-1) add(j+COLS,spread);
        };
        Array foods=s->get("foods"), randoms=s->get("ant_rng"), workers=s->get("colony_workers");
        std::vector<Patch> patches;
        std::vector<std::vector<int>> food_grid(35*19*4);
        for(int f=0;f<foods.size();++f) {
            Dictionary d=foods[f];
            Patch patch{d["pos"],int64_t(d["amount"]),d}; patch.resource=int(d.get("resource",0)); patch.layer=int(d.get("layer",-1)); patches.push_back(patch);
            if(patch.amount>0 && patch.layer>=-1 && patch.layer<sides) {
                int x=int(patch.pos.x/96.0f), y=int(patch.pos.y/96.0f);
                food_grid[x+y*35+(patch.layer+1)*35*19].push_back(f);
            }
        }
        int64_t harvested[3]={int64_t(s->get("delivered")),int64_t(s->get("rival_delivered")),int64_t(s->get("third_delivered"))};
        bool swapped=s->get("swapped_sides");
        int64_t tick=s->get("tick_number");
        bool first_food=false;
        auto follow=[&](int i,const int *route) {
            int side=layer[i],j=cell(p[i]),next=route[side*CELLS+j];
            if(next<0)return false;
            Vector2 center((j%COLS+0.5f)*14,(j/COLS+0.5f)*14),target((next%COLS+0.5f)*14,(next/COLS+0.5f)*14);
            Vector2 delta=target-center,offset=p[i]-center;
            if((std::abs(delta.x)>0 && std::abs(offset.y)>0.05) || (std::abs(delta.y)>0 && std::abs(offset.x)>0.05) || next==j)target=center;
            Vector2 direction=target-p[i];if(direction.length_squared()>0.0001f)angle_data[i]=direction.angle();
            Vector2 moved=p[i].move_toward(target,float(47*dt));int destination=cell(moved);
            if(destination==j || !cargo[i] || occupied[side*CELLS+destination]<6){
                if(destination!=j){occupied[side*CELLS+j]=std::max(0,occupied[side*CELLS+j]-1);++occupied[side*CELLS+destination];}
                p[i]=moved;
            }
            return next==j && p[i].distance_squared_to(center)<0.01f;
        };
        auto leave=[&](int i,Vector2 nest){
            int side=layer[i],j=cell(p[i]);occupied[side*CELLS+j]=std::max(0,occupied[side*CELLS+j]-1);
            layer[i]=-1;p[i]=nest+Vector2((worker_id[i]%3-1)*8,18);
        };
        auto bank_load=[&](int i,int side){
            if(kind[i])++protein_bank[side];else ++bank[side];
            ++resources[side*2+kind[i]];++harvested[side];++delivered[i];
            if(side==0)s->call("food_brought_home",i,int(kind[i]));
            kind[i]=0;cargo[i]=0;trip[i]=0;
        };
        for(int phase=0;phase<sides;++phase) {
            int side=(tick+phase)%sides;
            Vector2 nest=s->call("nest_position",side);
            PackedInt32Array indices=workers[side];
            for(int k=0;k<indices.size();++k) {
                int i=indices[k];
                if(hp[i]<=0 || role[i]!=0 || enemy[i]>=0) continue;
                if(physical && layer[i]==side){
                    done[i]=1;
                    if(!cargo[i]){
                        int cx=int(p[i].x/96.0f),cy=int(p[i].y/96.0f),nearest=-1;double best=INFINITY;
                        for(int y=std::max(0,cy-1);y<std::min(19,cy+2);++y)for(int x=std::max(0,cx-1);x<std::min(35,cx+2);++x)
                            for(int f:food_grid[x+y*35+(side+1)*35*19]){
                                if(patches[f].amount<=0)continue;
                                double distance=p[i].distance_squared_to(patches[f].pos);if(distance>=144)continue;
                                double score=distance/demand[side*2+patches[f].resource];
                                if(score<best || (nearest>=0 && score==best && f<nearest)){best=score;nearest=f;}
                            }
                        if(nearest>=0){--patches[nearest].amount;patches[nearest].changed=true;cargo[i]=1;kind[i]=patches[nearest].resource;if(side==0)s->call("food_picked_up",i);}
                    }
                    if(cargo[i]){
                        if(store_route[side*CELLS+cell(p[i])]<0){if(follow(i,exit_route))leave(i,nest);}
                        else if(follow(i,store_route) && bank[side]+protein_bank[side]+1<=room_capacity[side])bank_load(i,side);
                    }else if(follow(i,exit_route))leave(i,nest);
                    continue;
                }
                if(layer[i]!=-1)continue;
                done[i]=1;
                if(physical && cargo[i] && p[i].distance_squared_to(nest)<16*16){
                    if(bank[side]+protein_bank[side]+1<=room_capacity[side])for(int lane=0;lane<3;++lane){
                        int entry=entrances[side*3+(worker_id[i]+lane)%3];
                        if(entry>=0 && occupied[side*CELLS+entry]<6){
                            ++occupied[side*CELLS+entry];layer[i]=side;p[i]=Vector2((entry%COLS+0.5f)*14,(entry/COLS+0.5f)*14);trip[i]=0;break;
                        }
                    }
                    continue;
                }
                RandomNumberGenerator *rng=Object::cast_to<RandomNumberGenerator>(randoms[i]);
                Vector2 point=p[i]; double angle=angle_data[i];
                Vector2 travel_goal=point+Vector2::from_angle(float(angle))*150.0f;
                trip[i]+=dt;
                if(cargo[i]) {
                    travel_goal=nest;
                    Vector2 desired=(nest-point).normalized();
                    angle=Math::lerp_angle(angle,double(desired.angle()),std::min(1.0,dt*6));
                    deposit(fields[kind[i]?6+side:side*2],point,0.6/(1.0+trip[i]*0.018));
                    if(!physical && point.distance_squared_to(nest)<23*23) {
                        cargo[i]=0; ++harvested[side];
                        if(kind[i]) ++protein_bank[side]; else ++bank[side];
                        ++resources[side*2+kind[i]]; ++delivered[i]; trip[i]=0;
                        if(side==0) s->call("food_brought_home",i,int(kind[i]));
                        kind[i]=0;
                        angle+=PI+double(rng->randf_range(-0.6f,0.6f))*(swapped?-1:1);
                        if(side==0 && harvested[0]==1) first_food=true;
                    }
                } else {
                    deposit(fields[side*2+1],point,0.16/(1.0+trip[i]*0.06));
                    int nearest=-1; double best=INFINITY;
                    int cx=int(point.x/96.0f), cy=int(point.y/96.0f);
                    for(int y=std::max(0,cy-1);y<std::min(19,cy+2);++y)
                        for(int x=std::max(0,cx-1);x<std::min(35,cx+2);++x)
                            for(int f:food_grid[x+y*35]) {
                                if(patches[f].amount<=0) continue;
                                if(side==0 && avoided(patches[f].pos,zones,zone_count)) continue;
                                double distance=point.distance_squared_to(patches[f].pos);
                                if(distance>=86.0*86.0) continue;
                                double score=distance/demand[side*2+patches[f].resource];
                                if(score<best || (nearest>=0 && score==best && f<nearest)) { best=score; nearest=f; }
                            }
                    if(nearest>=0) {
                        travel_goal=patches[nearest].pos;
                        angle=Math::lerp_angle(angle,double((patches[nearest].pos-point).angle()),std::min(1.0,dt*7));
                        if(point.distance_squared_to(patches[nearest].pos)<15*15) {
                            --patches[nearest].amount; patches[nearest].changed=true;
                            cargo[i]=1; kind[i]=patches[nearest].resource; trip[i]=0; angle=(nest-point).angle();
                            if(side==0) s->call("food_picked_up",i);
                        }
                    } else {
                        auto sample=[&](double a) { int j=cell(point+Vector2::from_angle(float(a))*27.0f); return double(fields[side*2][j])*demand[side*2]+double(fields[6+side][j])*demand[side*2+1]; };
                        double forward=double(sample(angle))*1.06, left=sample(angle-0.65), right=sample(angle+0.65);
                        double turn=(std::max(left,right)>forward+0.025 && std::abs(left-right)>0.025)?(left>right?-0.65:0.65):0;
                        angle=Math::lerp_angle(angle,angle+turn,dt*3.5);
                        angle+=double(rng->randf_range(-1,1))*1.9*std::sqrt(dt)*(swapped?-1:1);
                        if(point.distance_squared_to(nest)<38*38) angle=Math::lerp_angle(angle,double((point-nest).angle()),dt*3);
                        travel_goal=point+Vector2::from_angle(float(angle))*150.0f;
                        if(order_kinds[i]==1 && point.distance_squared_to(order_goals[i])>90*90) {
                            travel_goal=order_goals[i];
                            angle=Math::lerp_angle(angle,double((travel_goal-point).angle()),std::min(1.0,dt*4));
                        }
                    }
                }
                if(side==0 && zone_count) {
                    Vector2 detour=avoid_direction(point,travel_goal,i,zones,zone_count);
                    if(detour.length_squared()>0.01f) angle=Math::lerp_angle(angle,double(detour.angle()),std::min(1.0,dt*10));
                }
                if(bank[side]>0 && point.distance_squared_to(nest)<30*30) hp[i]=std::min(double(maximum[i]),double(hp[i])+dt*0.6);
                double bonus=(doctrines[side]==1?1.08:1.0)*(cargo[i]?1.0:double(forage_multipliers[side]));
                Vector2 velocity=Vector2::from_angle(float(angle))*float(cargo[i]?43.0:52.0)*float(bonus)*terrain[cell(point)];
                Vector2 proposed=point+velocity*float(dt);
                point=side==0?safe_step(point,proposed,zones,zone_count):proposed;
                if(point.x<9 || point.x>3267) { angle=PI-angle; point.x=std::clamp(point.x,9.0f,3267.0f); }
                if(point.y<9 || point.y>1755) { angle=-angle; point.y=std::clamp(point.y,9.0f,1755.0f); }
                p[i]=point; angle_data[i]=angle;
            }
        }
        for(auto &patch:patches) if(patch.changed) patch.original["amount"]=patch.amount;
        active.resize(active_cells.size()); if(!active_cells.empty()) std::memcpy(active.ptrw(),active_cells.data(),active_cells.size()*sizeof(int));
        s->set("tunnel_occupancy",occupancy); s->set("layers",layers);
        s->set("positions",positions); s->set("headings",headings); s->set("trips",trips); s->set("health",health);
        s->set("carrying",carrying); s->set("cargo_resource",cargo_kind); s->set("deliveries",deliveries); s->set("food_stores",stores); s->set("protein_stores",protein_stores); s->set("resource_delivered",resource_delivered);
        s->set("protein_scent",protein); s->set("rival_protein_scent",rival_protein); s->set("third_protein_scent",third_protein);
        s->set("food_scent",food); s->set("home_scent",home); s->set("rival_food_scent",rival_food); s->set("rival_home_scent",rival_home);
        s->set("third_food_scent",third_food); s->set("third_home_scent",third_home);
        s->set("active_scent",active); s->set("scent_active",membership); s->set("trails_dirty",true);
        s->set("delivered",harvested[0]); s->set("rival_delivered",harvested[1]); s->set("third_delivered",harvested[2]);
        if(first_food) s->set("message","First food delivered. Returning workers leave a trail for other scouts.");
        return processed;
    }
};

void initialize(ModuleInitializationLevel level) { if(level==MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<AntKernel>(); }
void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT ant_kernel_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *init) {
    GDExtensionBinding::InitObject binding(get_proc,library,init);
    binding.register_initializer(initialize); binding.register_terminator(uninitialize);
    binding.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return binding.init();
}
