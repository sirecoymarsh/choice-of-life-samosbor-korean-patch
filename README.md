# Choice of Life: Samosbor 비공식 한국어 패치

Steam판 **1.08**용 한국어 패치입니다. 러시아어 원문을 기준으로 영어 언어 슬롯을 한국어로 교체합니다.

이 저장소는 원본 게임 자산을 포함하지 않습니다. 약 130KB의 MSDelta 패치를 정품 Steam 1.08 원본에 적용하며, BepInEx는 설치할 때 공식 GitHub 릴리스에서 내려받아 SHA-256을 검증합니다.

## 추가·변경 사항

원판(Steam판 『Choice of Life: Samosbor』 1.08)과 비교해 이 패치가 바꾸거나 더한 것입니다. 괄호 안은 근거(커밋, 파일 이름)입니다.

### 번역 범위

- **번역 원문**: 러시아어 원문을 기준으로 옮겼습니다(영문판을 거치지 않음).
- **번역한 글**: 게임 문자열 4,025개를 한국어로 옮겼습니다. 바뀐 것은 `Choice of Life - Samosbor_Data/sharedassets0.assets` 안의 Unity 오브젝트 두 개(PathID 102, 104)뿐입니다(`install_manifest.json`의 `translation_count`, `changed_unity_object_path_ids`). 본문·선택지·메뉴처럼 그 파일에 든 글이 모두 대상입니다(추정: 문자열이 어느 화면 글인지 나눈 기록은 저장소에 없음).
- **언어 자리**: 한국어는 게임의 **영어** 언어 자리에 들어갑니다. 설치한 동안에는 영어를 고를 수 없고, 게임 설정에서 언어를 「한국어」로 고르면 됩니다. 러시아어·튀르키예어·브라질 포르투갈어 자리는 그대로 남겨 두었습니다.
- **검수 기록**: 설치 자료에는 QA·검토에서 남은 문제가 0건으로 적혀 있습니다(`qa_issue_count`, `review_issue_count`).
- 그림 속 글자, 영상 자막을 따로 고친 기록은 없습니다(추정: 그림 글자는 원문 그대로).

### 화면 개선 (한글 글꼴)

- **한글 대체 글꼴 플러그인**: BepInEx 플러그인 `SamosborKoreanFont.dll`(소스 `src/SamosborKoreanFont.cs`)이 함께 든 Noto Sans KR 가변 글꼴(`NotoSansKR-VF.ttf`, OFL)로 TextMeshPro 동적 글꼴을 만들어, 게임의 모든 TMP 글꼴에 대체 글꼴(fallback)로 붙입니다. 원래 글꼴에 없는 한글만 이 글꼴로 그려집니다.
- **미리 넣는 글자**: 번역에 쓰인 글자 1,155자(한글 음절 1,076자 포함, `hangul_charset.txt`)를 시작할 때 글꼴에 미리 넣어 처음 나올 때 끊기지 않게 합니다.
- **장면이 바뀔 때도 적용**: 장면을 불러올 때마다, 그리고 5초마다 새로 생긴 글자 칸을 찾아 한글 글꼴을 다시 붙입니다.

### 설치·제거 방식

- **차분만 배포**: 원본 게임 자산은 들어 있지 않고, 약 130KB의 MSDelta 차분(`payload/patches/sharedassets0.assets.msdelta`)만 들어 있습니다. 윈도에 들어 있는 `msdelta.dll`을 쓰는 적용 도구(`tools/MsDeltaTool.cs`)를 설치 때 PowerShell에서 바로 컴파일해 씁니다.
- **원본 확인(해시)**: `sharedassets0.assets`의 크기(11,098,360바이트)와 SHA-256이 Steam 1.08과 다르면 설치를 멈추고 Steam 파일 무결성 검사를 먼저 하라고 알립니다. 이미 한국어 자산이 들어 있어도 멈춥니다. 차분 파일 자체의 해시도 먼저 확인합니다.
- **BepInEx 내려받기**: BepInEx 5.4.23.5(win-x64)를 공식 GitHub 릴리스에서 내려받고 크기·SHA-256을 확인합니다. 미리 받은 ZIP을 `-BepInExArchive`로 줄 수도 있습니다.
- **게임 폴더 자동 찾기**: 레지스트리의 Steam 경로와 각 드라이브의 Steam 라이브러리(`libraryfolders.vdf`)를 뒤져 `Choice of Life Samosbor` 폴더를 찾습니다. 못 찾으면 `-GameRoot`로 직접 지정합니다.
- **게임 실행 중 확인**: 게임이 켜져 있으면 설치·복원을 멈춥니다.
- **임시 폴더에서 먼저 만들기**: 모든 파일(BepInEx 실행 파일 22개, 글꼴 플러그인 4개, 한국어 자산 1개)을 임시 폴더에 만들고 하나하나 해시를 확인한 뒤, 게임 폴더에 넣을 때도 임시 이름으로 복사해 해시를 확인하고 바꿔치기합니다. 넣은 뒤 한 번 더 전부 확인합니다.
- **백업**: 덮어쓸 원본은 `%LOCALAPPDATA%\SamosborKoreanPatch\Backups\(날짜-시각-임의값)\files`에 해시를 확인해 보관하고, 설치 상태(`install_state.json`)와 복원 스크립트 사본도 같이 둡니다.
- **실패 시 되돌리기**: 설치 도중 실패하면 넣은 파일을 거꾸로 되돌리고 상태를 `failed_rolled_back`으로 남깁니다.
- **설치 확인**: `Verify_Steam_KO.ps1`가 설치된 파일의 해시를 모두 확인합니다.
- **원상 복원**: `Restore_Steam_KO.ps1`가 설치 뒤 누가 바꾼 파일이 있으면 멈추고, 없으면 원본을 되돌리고 설치 때 새로 만든 파일과 (설치 전에 없던) `BepInEx` 폴더를 지운 뒤 다시 확인합니다. Steam의 「설치된 파일 무결성 확인」으로도 원본을 되찾을 수 있습니다.
- **지원 판본**: Steam판 1.08만 지원합니다.

### 판별 변경 기록

| 판 | 날짜 | 내용 |
|---|---|---|
| 1.08 (r2) | 2026-08-03 | 첫 공개. 러시아어 원문 기준 4,025개 문자열, Noto Sans KR 대체 글꼴 플러그인, MSDelta 차분 설치, BepInEx 자동 내려받기, 백업·확인·복원 스크립트, 글꼴 플러그인과 델타 도구 소스 공개(18b6e0a). 패치 id가 `...-steam-1.08-r2-delta`라 내부적으로 두 번째 개정판으로 보입니다(추정). |

릴리스(태그)는 없고, 저장소를 **Code → Download ZIP**으로 받아 씁니다.

### 알려진 문제

- Steam 1.08 말고 다른 판(업데이트된 판, 다른 판매처)은 해시가 달라 설치되지 않습니다.
- 설치한 동안 영어는 쓸 수 없습니다.
- 게임이 업데이트되어 `sharedassets0.assets`가 바뀌면 한국어가 사라지므로 복원 뒤 새 판 패치가 필요합니다(추정).

## 설치

1. 게임을 완전히 종료합니다.
2. 저장소의 **Code → Download ZIP**으로 내려받은 뒤 압축을 풉니다.
3. PowerShell에서 다음 명령을 실행합니다.
4. 게임 설정에서 언어를 `한국어`로 선택합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install_Steam_KO.ps1
```

Steam 라이브러리를 자동으로 찾지 못하면 게임 폴더를 직접 지정합니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install_Steam_KO.ps1 -GameRoot "게임 폴더"
```

설치기는 공식 `BepInEx_win_x64_5.4.23.5.zip`을 자동으로 내려받습니다. 미리 내려받은 파일을 사용할 수도 있습니다.

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install_Steam_KO.ps1 -BepInExArchive ".\BepInEx_win_x64_5.4.23.5.zip"
```

## 설치 확인

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Verify_Steam_KO.ps1 -GameRoot "게임 폴더"
```

## 원상 복원

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Restore_Steam_KO.ps1
```

설치 당시 원본 파일은 `%LOCALAPPDATA%\SamosborKoreanPatch\Backups`에 해시 검증된 상태로 보관됩니다. Steam의 **설치된 파일 무결성 확인**으로도 원본을 복구할 수 있습니다.

## 검증 정보

- 대상: Steam 1.08
- 번역 문자열: 4,025개
- 원본 자산 SHA-256: `1467e8a81eebfef7d1f6657ab34462108343bc1297a219a4ce57a4947de40339`
- 패치 자산 SHA-256: `24b993ad5608c4f57a234ed0f4dcdcecca260fd56c3d4568265983d2f5572713`
- MSDelta SHA-256: `b7bc4ebd1bf2a813ce96176c523d2160e28f70c09df469ae58f644646ca01b63`
- BepInEx 공식 ZIP SHA-256: `82f9878551030f54657792c0740d9d51a09500eeae1fba21106b0c441e6732c4`

## 포함된 오픈 소스 구성 요소

- BepInEx 5.4.23.5: 설치 시 공식 릴리스에서 다운로드
- Noto Sans KR: `payload/BepInEx/plugins/SamosborKorean/OFL.txt` 참조

이 패치는 비공식 팬 번역입니다.
