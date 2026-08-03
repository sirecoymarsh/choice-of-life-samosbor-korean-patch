# Choice of Life: Samosbor 비공식 한국어 패치

Steam판 **1.08**용 한국어 패치입니다. 러시아어 원문을 기준으로 영어 언어 슬롯을 한국어로 교체합니다.

이 저장소는 원본 게임 자산을 포함하지 않습니다. 약 130KB의 MSDelta 패치를 정품 Steam 1.08 원본에 적용하며, BepInEx는 설치할 때 공식 GitHub 릴리스에서 내려받아 SHA-256을 검증합니다.

## 번역 및 구성

- 러시아어 원문 기준 4,025개 문자열 한국어화
- 러시아어·튀르키예어·브라질 포르투갈어 슬롯 보존
- Noto Sans KR 동적 TMP 대체 글꼴 포함
- 원본 `sharedassets0.assets` 해시와 크기가 Steam 1.08 기준과 다르면 설치 중단
- 설치 전 원본 자동 백업, 설치 후 해시 검증, 복원 스크립트 제공
- 글꼴 플러그인 C# 소스와 델타 적용 도구 소스 공개

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
