param(
    [string]$BackupRoot = (Join-Path $env:LOCALAPPDATA "SamosborKoreanPatch\Backups")
)

$ErrorActionPreference = "Stop"

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
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
        throw "Temporary restore copy hash mismatch: $Target"
    }
    Move-Item -LiteralPath $temp -Destination $Target -Force
}

$BackupRoot = [IO.Path]::GetFullPath($BackupRoot)
$activePointer = Join-Path $BackupRoot "active_install.json"
if (-not (Test-Path -LiteralPath $activePointer -PathType Leaf)) {
    throw "활성 설치 기록을 찾을 수 없습니다: $activePointer"
}
$pointer = Get-Content -Raw -Encoding UTF8 -LiteralPath $activePointer | ConvertFrom-Json
$backupDir = [IO.Path]::GetFullPath([string]$pointer.backup_dir)
$statePath = Join-Path $backupDir "install_state.json"
$backupFilesRoot = Join-Path $backupDir "files"
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    throw "설치 상태 파일이 없습니다: $statePath"
}
$state = Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json
$GameRoot = [IO.Path]::GetFullPath([string]$state.game_root)

foreach ($processName in @("Choice of Life - Samosbor")) {
    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        throw "게임이 실행 중입니다. 종료한 뒤 다시 복원하세요: $processName"
    }
}

foreach ($entry in $state.files) {
    $target = Join-Path $GameRoot ($entry.path.Replace('/', '\'))
    Assert-WithinRoot $GameRoot $target
    if ($entry.existed_before) {
        $backupPath = Join-Path $backupFilesRoot ($entry.backup_path.Replace('/', '\'))
        if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            throw "Backup file missing: $($entry.path)"
        }
        if ((Get-Sha256 $backupPath) -ne [string]$entry.original_sha256) {
            throw "Backup hash mismatch: $($entry.path)"
        }
    }
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $liveHash = Get-Sha256 $target
        $allowed = @([string]$entry.installed_sha256)
        if ($entry.existed_before) {
            $allowed += [string]$entry.original_sha256
        }
        if ($liveHash -notin $allowed) {
            throw "복원을 중단했습니다. 설치 이후 알 수 없는 변경이 있습니다: $($entry.path) ($liveHash)"
        }
    }
}

for ($index = $state.files.Count - 1; $index -ge 0; $index--) {
    $entry = $state.files[$index]
    $target = Join-Path $GameRoot ($entry.path.Replace('/', '\'))
    if ($entry.existed_before) {
        $backupPath = Join-Path $backupFilesRoot ($entry.backup_path.Replace('/', '\'))
        Copy-Atomic $backupPath $target ([string]$entry.original_sha256)
    }
    elseif (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
    }
}

foreach ($rootState in $state.cleanup_roots) {
    if (-not $rootState.existed_before) {
        $rootPath = Join-Path $GameRoot ($rootState.path.Replace('/', '\'))
        Assert-WithinRoot $GameRoot $rootPath
        if (Test-Path -LiteralPath $rootPath) {
            Remove-Item -LiteralPath $rootPath -Recurse -Force
        }
    }
}

foreach ($entry in $state.files) {
    $target = Join-Path $GameRoot ($entry.path.Replace('/', '\'))
    if ($entry.existed_before) {
        if ((Get-Sha256 $target) -ne [string]$entry.original_sha256) {
            throw "Post-restore hash mismatch: $($entry.path)"
        }
    }
    elseif (Test-Path -LiteralPath $target -PathType Leaf) {
        throw "Post-restore cleanup failed: $($entry.path)"
    }
}

$state.status = "restored"
$state | Add-Member -NotePropertyName "restored_at" -NotePropertyValue (Get-Date).ToString("o") -Force
$state | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $statePath
Remove-Item -LiteralPath $activePointer -Force
Write-Host "원본 복원 완료"
Write-Host "복구 기록: $backupDir"
