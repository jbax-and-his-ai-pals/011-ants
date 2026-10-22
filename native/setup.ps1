param()
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$dependencyDirectory = Join-Path $projectDirectory '.tools'
New-Item -ItemType Directory -Path $dependencyDirectory -Force | Out-Null

function Get-PortableDependency($Name, $Url, $Sha256, $ExtractedName, $DirectoryName) {
    $destination = [IO.Path]::GetFullPath((Join-Path $dependencyDirectory $DirectoryName))
    if (Test-Path -LiteralPath $destination -PathType Container) { return }
    $archive = Join-Path $dependencyDirectory "$Name.zip"
    Invoke-WebRequest -Uri $Url -OutFile $archive
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Sha256) {
        throw "Checksum mismatch for $Name"
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $dependencyDirectory -Force
    $sourceDirectory = [IO.Path]::GetFullPath((Join-Path $dependencyDirectory $ExtractedName))
    $allowedPrefix = [IO.Path]::GetFullPath($dependencyDirectory) + [IO.Path]::DirectorySeparatorChar
    # Verify both resolved directory targets before moving an extracted tree.
    if (-not $sourceDirectory.StartsWith($allowedPrefix) -or -not $destination.StartsWith($allowedPrefix)) {
        throw 'Dependency paths must remain inside the project .tools folder'
    }
    if ($sourceDirectory -ne $destination) { Move-Item -LiteralPath $sourceDirectory -Destination $destination }
}

Get-PortableDependency 'zig' 'https://ziglang.org/download/0.13.0/zig-windows-x86_64-0.13.0.zip' 'D859994725EF9402381E557C60BB57497215682E355204D754EE3DF75EE3C158' 'zig-windows-x86_64-0.13.0' 'zig-windows-x86_64-0.13.0'
Get-PortableDependency 'godot-cpp' 'https://github.com/godotengine/godot-cpp/archive/b0e3b1e4b78a606f48d162898afb5eeda533d2a9.zip' 'D65A102647A2EE4BF0F3DE8C97050FF9E4C0EBB5C4C4CBAED3EA12C436F93909' 'godot-cpp-b0e3b1e4b78a606f48d162898afb5eeda533d2a9' 'godot-cpp-4.4'
Write-Output 'Native build dependencies are ready in .tools.'
