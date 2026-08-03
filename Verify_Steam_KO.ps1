param(
    [string]$GameRoot = ""
)

$ErrorActionPreference = "Stop"
$PackageRoot = $PSScriptRoot
$PayloadRoot = Join-Path $PackageRoot "payload"
$Manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PackageRoot "install_manifest.json") | ConvertFrom-Json

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Find-SteamGameRoot {
    $libraryRoots = @()
    try {
        $steamPath = (Get-ItemProperty -LiteralPath "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steamPath) {
            $libraryRoots += [IO.Path]::GetFullPath($steamPath)
        }
    }
    catch {}
    if (${env:ProgramFiles(x86)}) {
        $libraryRoots += (Join-Path ${env:ProgramFiles(x86)} "Steam")
    }
    foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
        $libraryRoots += (Join-Path $drive.Root "SteamLibrary")
        $libraryRoots += (Join-Path $drive.Root "Steam")
        $libraryRoots += $drive.Root
    }
    foreach ($steamRoot in @($libraryRoots | Select-Object -Unique)) {
        $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            $text = Get-Content -Raw -LiteralPath $vdf
            foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $libraryRoots += $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    foreach ($library in @($libraryRoots | Select-Object -Unique)) {
        $candidate = Join-Path $library "steamapps\common\Choice of Life Samosbor"
        if (Test-Path -LiteralPath (Join-Path $candidate "Choice of Life - Samosbor.exe") -PathType Leaf) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    throw "Steam 게임 폴더를 자동으로 찾지 못했습니다. -GameRoot 옵션으로 직접 지정하세요."
}

if ([string]::IsNullOrWhiteSpace($GameRoot)) {
    $GameRoot = Find-SteamGameRoot
}
$GameRoot = [IO.Path]::GetFullPath($GameRoot)

$checked = 0
foreach ($file in $Manifest.files) {
    $target = Join-Path $GameRoot ($file.path.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Installed file missing: $($file.path)"
    }
    if ((Get-Sha256 $target) -ne [string]$file.sha256) {
        throw "Installed file hash mismatch: $($file.path)"
    }
    $checked++
}
Write-Host "설치 파일 해시 검증 통과: ${checked}개"
