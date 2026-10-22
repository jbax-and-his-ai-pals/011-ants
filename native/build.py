"""Rebuild the native hot loops with portable Zig and official godot-cpp 4.4.

Dependencies live in .tools; see native/README.md for setup and licensing.
"""
from pathlib import Path
import concurrent.futures, os, subprocess, sys, hashlib

ROOT = Path(__file__).resolve().parent.parent
SDK = ROOT / '.tools/godot-cpp-4.4'
ZIG = ROOT / '.tools/zig-windows-x86_64-0.13.0/zig.exe'
sys.path.insert(0, str(SDK))
import binding_generator, build_profile

profile = ROOT / 'native/build_profile.json'
signature = hashlib.sha256(profile.read_bytes() + Path(__file__).read_bytes()).hexdigest()[:16]
stamp = SDK / 'gen/profile_signature'
assert (SDK / 'gen').resolve().is_relative_to((ROOT / '.tools').resolve())
if not stamp.exists() or stamp.read_text() != signature:
    api = build_profile.generate_trimmed_api(str(SDK / 'gdextension/extension_api.json'), str(ROOT / 'native/build_profile.json'))
    binding_generator._generate_bindings(api, str(SDK / 'gdextension/extension_api.json'), False, output_dir=str(SDK))
    stamp.write_text(signature)

env = dict(os.environ)
env['ZIG_GLOBAL_CACHE_DIR'] = str(ROOT / '.tools/zig-global-cache')
env['ZIG_LOCAL_CACHE_DIR'] = str(ROOT / '.tools/zig-local-cache')
obj = ROOT / '.tools/objects' / signature
obj.mkdir(parents=True, exist_ok=True)
out = ROOT / 'native/bin'
out.mkdir(exist_ok=True)
flags = ['-target', 'x86_64-windows-gnu', '-std=c++17', '-O3', '-DNDEBUG', '-DGDEXTENSION', '-fno-exceptions', '-ffp-contract=off']
for folder in ['include', 'gen/include', 'gdextension']:
    flags += ['-I', str(SDK / folder)]
sources = list((SDK / 'src').rglob('*.cpp')) + list((SDK / 'gen/src').rglob('*.cpp')) + [ROOT / 'native/ant_kernel.cpp']

def compile_one(source):
    name = str(source.relative_to(ROOT)).replace('\\', '_').replace('/', '_') + '.o'
    target = obj / name
    if not target.exists() or target.stat().st_mtime < source.stat().st_mtime:
        result = subprocess.run([str(ZIG), 'c++', *flags, '-c', str(source), '-o', str(target)], env=env, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(source.name + '\n' + result.stdout + result.stderr)
    return target

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    objects = list(pool.map(compile_one, sources))
subprocess.run([str(ZIG), 'c++', '-target', 'x86_64-windows-gnu', '-shared', '-static', '-o', str(out/'ant_kernel.dll'), *map(str,objects)], env=env, check=True)
print(f'Built native/bin/ant_kernel.dll ({len(sources)} source files).')
