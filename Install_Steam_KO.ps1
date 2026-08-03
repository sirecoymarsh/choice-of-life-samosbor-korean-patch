param(
    [string]$GameRoot = "",
    [string]$BackupRoot = (Join-Path $env:LOCALAPPDATA "SamosborKoreanPatch\Backups"),
    [string]$BepInExArchive = ""
)

$ErrorActionPreference = "Stop"
$PackageRoot = $PSScriptRoot
$ManifestPath = Join-Path $PackageRoot "install_manifest.json"
$PluginPayload = Join-Path $PackageRoot "payload\BepInEx\plugins\SamosborKorean"
$DeltaPath = Join-Path $PackageRoot "payload\patches\sharedassets0.assets.msdelta"
$DeltaToolPath = Join-Path $PackageRoot "tools\MsDeltaTool.cs"

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Find-SteamGameRoot {
    $libraryRoots = @()
    try {
        $steamPath = (Get-ItemProperty -LiteralPath "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steamPath) { $libraryRoots += [IO.Path]::GetFullPath($steamPath) }
    }
    catch {}
    if (${env:ProgramFiles(x86)}) { $libraryRoots += (Join-Path ${env:ProgramFiles(x86)} "Steam") }
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

function Assert-WithinRoot([string]$Root, [string]$Candidate) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    if (-not $candidateFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes the intended game root: $candidateFull"
    }
}

function Copy-Atomic([string]$Source, [string]$Target, [string]$ExpectedHash) {
    $parent = Split-Path -Parent $Target
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temp = "$Target.samosbor-ko.tmp.$([Guid]::NewGuid().ToString('N'))"
    Copy-Item -LiteralPath $Source -Destination $temp -Force
    if ((Get-Sha256 $temp) -ne $ExpectedHash) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw "Temporary copy hash mismatch: $Target"
    }
    Move-Item -LiteralPath $temp -Destination $Target -Force
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw "Missing install manifest: $ManifestPath" }
if (-not (Test-Path -LiteralPath $PluginPayload -PathType Container)) { throw "Missing plugin payload: $PluginPayload" }
if (-not (Test-Path -LiteralPath $DeltaPath -PathType Leaf)) { throw "Missing delta: $DeltaPath" }
if (-not (Test-Path -LiteralPath $DeltaToolPath -PathType Leaf)) { throw "Missing delta tool source: $DeltaToolPath" }
$Manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json

if ((Get-Item -LiteralPath $DeltaPath).Length -ne [long]$Manifest.delta.size -or
    (Get-Sha256 $DeltaPath) -ne [string]$Manifest.delta.sha256) {
    throw "Delta file verification failed."
}

if ([string]::IsNullOrWhiteSpace($GameRoot)) { $GameRoot = Find-SteamGameRoot }
$GameRoot = [IO.Path]::GetFullPath($GameRoot)
$BackupRoot = [IO.Path]::GetFullPath($BackupRoot)
$exePath = Join-Path $GameRoot ([string]$Manifest.game_exe)
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Game executable not found: $exePath" }

foreach ($processName in $Manifest.process_names) {
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        throw "게임이 실행 중입니다. 종료한 뒤 다시 설치하세요: $processName"
    }
}

$assetTarget = Join-Path $GameRoot ($Manifest.source_asset.path.Replace('/', '\'))
Assert-WithinRoot $GameRoot $assetTarget
if (-not (Test-Path -LiteralPath $assetTarget -PathType Leaf)) { throw "Game asset missing: $assetTarget" }
$liveAssetHash = Get-Sha256 $assetTarget
if ($liveAssetHash -eq [string]$Manifest.patched_asset_sha256) { throw "이미 동일한 한국어 패치 자산이 설치되어 있습니다." }
if ((Get-Item -LiteralPath $assetTarget).Length -ne [long]$Manifest.source_asset.size -or
    $liveAssetHash -ne [string]$Manifest.source_asset.sha256) {
    throw "지원하지 않는 게임 자산입니다. Steam 파일 무결성 검사를 먼저 실행하세요. 현재 해시: $liveAssetHash"
}

New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
$activePointer = Join-Path $BackupRoot "active_install.json"
if (Test-Path -LiteralPath $activePointer) {
    throw "활성 설치 기록이 이미 있습니다. 먼저 Restore_Steam_KO.ps1로 복원하세요: $activePointer"
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("SamosborKO-" + [Guid]::NewGuid().ToString("N"))
$stageRoot = Join-Path $tempRoot "stage"
$archivePath = Join-Path $tempRoot "BepInEx.zip"
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

try {
    if ([string]::IsNullOrWhiteSpace($BepInExArchive)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "공식 BepInEx $($Manifest.bepinex.version) 다운로드 중..."
        Invoke-WebRequest -UseBasicParsing -Uri ([string]$Manifest.bepinex.url) -OutFile $archivePath
    }
    else {
        $providedArchive = [IO.Path]::GetFullPath($BepInExArchive)
        if (-not (Test-Path -LiteralPath $providedArchive -PathType Leaf)) { throw "BepInEx archive not found: $providedArchive" }
        Copy-Item -LiteralPath $providedArchive -Destination $archivePath -Force
    }
    if ((Get-Item -LiteralPath $archivePath).Length -ne [long]$Manifest.bepinex.size -or
        (Get-Sha256 $archivePath) -ne [string]$Manifest.bepinex.sha256) {
        throw "Official BepInEx archive verification failed."
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $stageRoot -Force

    $stagePlugin = Join-Path $stageRoot "BepInEx\plugins\SamosborKorean"
    New-Item -ItemType Directory -Force -Path $stagePlugin | Out-Null
    Get-ChildItem -LiteralPath $PluginPayload -File | Copy-Item -Destination $stagePlugin -Force

    if (-not ("MsDeltaTool" -as [type])) { Add-Type -Path $DeltaToolPath }
    $stagedAsset = Join-Path $stageRoot ($Manifest.source_asset.path.Replace('/', '\'))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stagedAsset) | Out-Null
    [MsDeltaTool]::Apply($assetTarget, $DeltaPath, $stagedAsset)

    $packageFiles = @()
    foreach ($file in $Manifest.files) {
        $relative = [string]$file.path
        $source = Join-Path $stageRoot ($relative.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Staged file missing: $relative" }
        $actualLength = (Get-Item -LiteralPath $source).Length
        $actualHash = Get-Sha256 $source
        if ($actualLength -ne [long]$file.size -or $actualHash -ne [string]$file.sha256) {
            throw "Staged file verification failed: $relative"
        }
        $target = Join-Path $GameRoot ($relative.Replace('/', '\'))
        Assert-WithinRoot $GameRoot $target
        $packageFiles += [pscustomobject]@{ Relative=$relative; Source=$source; Target=$target; Hash=$actualHash }
    }

    $backupName = (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + [Guid]::NewGuid().ToString("N").Substring(0, 8)
    $backupDir = Join-Path $BackupRoot $backupName
    $backupFilesRoot = Join-Path $backupDir "files"
    New-Item -ItemType Directory -Force -Path $backupFilesRoot | Out-Null

    $cleanupRootStates = @()
    foreach ($relativeRoot in $Manifest.cleanup_roots) {
        $rootPath = Join-Path $GameRoot ($relativeRoot.Replace('/', '\'))
        Assert-WithinRoot $GameRoot $rootPath
        $cleanupRootStates += [pscustomobject]@{ path=[string]$relativeRoot; existed_before=[bool](Test-Path -LiteralPath $rootPath) }
    }

    $stateFiles = @()
    foreach ($file in $packageFiles) {
        $existed = Test-Path -LiteralPath $file.Target -PathType Leaf
        $originalHash = $null
        $backupRelative = $null
        if ($existed) {
            $originalHash = Get-Sha256 $file.Target
            $backupRelative = $file.Relative
            $backupPath = Join-Path $backupFilesRoot ($backupRelative.Replace('/', '\'))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
            Copy-Item -LiteralPath $file.Target -Destination $backupPath -Force
            if ((Get-Sha256 $backupPath) -ne $originalHash) { throw "Backup verification failed: $($file.Relative)" }
        }
        $stateFiles += [pscustomobject]@{
            path=$file.Relative; existed_before=[bool]$existed; original_sha256=$originalHash;
            installed_sha256=$file.Hash; backup_path=$backupRelative
        }
    }

    $state = [ordered]@{
        schema_version=1; patch_id=[string]$Manifest.patch_id; status="installing";
        installed_at=(Get-Date).ToString("o"); game_root=$GameRoot; backup_dir=$backupDir;
        files=$stateFiles; cleanup_roots=$cleanupRootStates
    }
    $statePath = Join-Path $backupDir "install_state.json"
    $state | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statePath
    Copy-Item -LiteralPath (Join-Path $PackageRoot "Restore_Steam_KO.ps1") -Destination (Join-Path $backupDir "Restore_Steam_KO.ps1") -Force

    try {
        foreach ($file in $packageFiles) { Copy-Atomic $file.Source $file.Target $file.Hash }
        foreach ($file in $packageFiles) {
            if ((Get-Sha256 $file.Target) -ne $file.Hash) { throw "Post-install hash mismatch: $($file.Relative)" }
        }
        $state.status = "installed"
        $state | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statePath
        [ordered]@{ patch_id=[string]$Manifest.patch_id; game_root=$GameRoot; backup_dir=$backupDir; state_path=$statePath } |
            ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -LiteralPath $activePointer
        Write-Host "한국어 패치 설치 완료"
        Write-Host "백업: $backupDir"
    }
    catch {
        $failure = $_
        for ($index = $stateFiles.Count - 1; $index -ge 0; $index--) {
            $entry = $stateFiles[$index]
            $target = Join-Path $GameRoot ($entry.path.Replace('/', '\'))
            try {
                if ($entry.existed_before) {
                    $backupPath = Join-Path $backupFilesRoot ($entry.backup_path.Replace('/', '\'))
                    Copy-Atomic $backupPath $target $entry.original_sha256
                }
                elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
            }
            catch { Write-Warning "Rollback failed for $($entry.path): $($_.Exception.Message)" }
        }
        $state.status = "failed_rolled_back"
        $state.failure = $failure.Exception.Message
        $state | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statePath
        throw $failure
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
