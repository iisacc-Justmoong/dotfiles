# Windows Workspace 실행 검증

`projects.json`은 GitHub에서 확인한 50개 프로젝트의 실제 경로 및 프로젝트별 빌드·런타임 명령을 보존한다. Time Scopes와 Alright은 사용자 지정에 따라 macOS 전용으로 제외된다. 프로필 README 저장소는 실행 대상이 없는 문서 저장소이다.

```powershell
python -X utf8 Windows/workspace_runner.py --list
python -X utf8 Windows/workspace_runner.py --projects iiActorObject TextEditor
python -X utf8 Windows/workspace_runner.py --projects WhatSon --phase all
python -X utf8 Windows/workspace_runner.py --projects Society --launch
```

기본 단계는 `runtime`이며 `--phase all`은 빌드 후 실행한다. 결과와 원문 로그는 `dotfiles/build/workspace-runs/<실행 시각>/`에 보존된다. 한 프로젝트가 실패해도 다음 프로젝트를 검사하며 종료 코드는 전체 실패 여부를 반영한다. 프로젝트 내부의 실패 단계 뒤 명령은 실행하지 않는다.

`--launch`는 지정한 데스크톱 앱을 의존성 경로와 함께 열며, 사용자가 창을 닫을 때까지 유지한다. 자동 검증의 3초 관찰 후 종료 동작과 용도가 구분된다.

네이티브 GUI는 해당 프로세스가 소유한 창을 3초간 관찰하고 WM_CLOSE를 보낸 뒤 정상 종료 코드까지 검사한다. 라이브러리는 실제 CTest 테스트 실행파일을 실행한다. 웹 프로젝트는 빈 로컬 포트를 선택하여 서버를 기동하고 HTTP 200 응답과 HTML 내용을 확인한 뒤, 러너가 생성한 프로세스와 하위 프로세스를 종료한다. 서버의 조기 종료와 응답 시간 초과도 실패로 기록하며, 프로젝트별 런타임 통합 검증을 이어서 수행한다. 실제 브라우저 검증 및 Windows 네이티브 Ruby·Rails·Redis 검증의 별도 증거는 Workspace 검증 보고서에 기록된다. 모델·서비스 자격 증명이 필요한 기능은 fixture와 CPU 계약 검증을 사용하며, 실제 유료 모델 추론이나 운영 서버 검증으로 해석하지 않는다.

`iisacc.com --phase all`은 frontend 빌드, RubyInstaller 4.0.6의 Bundler 설치, frontend HTTP·lint, Rails·Redis의 실제 네이티브 실행 순서이다. Ruby C 확장 11개는 같은 머신의 UCRT GCC로 컴파일하며 Nokogiri는 MSYS2 UCRT의 libxml2·libxslt를 사용한다. nio4r은 원본 라이브러리의 Windows 전용 순수 Ruby 구현으로 실행된다. 실행 바이너리는 Windows PE이며 Docker·WSL을 호출하지 않는다. GraphQL·계정·SSO·활동 기록 검사와 HTTP health, Redis AOF 재시작 지속성을 일회용 loopback 인스턴스에서 확인한다. 설치 도구는 `.windows-validation/build/tools/`, gem과 실행 기록은 `iisacc.com/build/`에 보존된다. 자세한 명령은 `Webservice/iisacc.com/docs/RAILS_REDIS.md`를 따른다.

Product·SDK 상위 정책 저장소는 `build/`에 Python 바이트코드를 컴파일한 뒤 실제 Python 검사 프로세스를 실행한다. SDK 설치기는 Git for Windows의 네이티브 Bash를 선택하며 System32의 WSL Bash shim을 거부한다.

이 머신의 backend 의존성 설치 재실행 스크립트는 `D:\Workspace\.windows-validation\build\bootstrap_native_backend.ps1`이다. RubyInstaller 원본 SHA256 확인, Devkit·UCRT 라이브러리·Bundler 설치 및 Redis 실행파일 확인을 포함한다. 재실행 검증 원문은 같은 디렉터리의 `native-backend-bootstrap-replay.log`이다.

환경의 절대 도구 경로는 이 머신에서 검증한 설치본이다. 다른 머신에서는 manifest의 `environment`와 `path`를 해당 설치 위치에 맞춘다. 소스 및 빌드 위치의 `{workspace}`는 자동으로 현재 Workspace에 치환된다. CMake 빌드 디렉터리는 각 저장소의 `build/`이다. 다른 플랫폼을 위한 기존 `macOS/Setup.sh`는 유지된다.

PATH는 필요한 설치 의존성과 현재 머신의 환경에서 구성하고, 대소문자 및 경로 구분자가 다른 중복 항목을 제거한다. 빌드 폴더와 설치 폴더 전체를 동시에 나열하여 cmd.exe의 환경 길이 제한으로 npm 실행파일 검색이 실패하는 상황을 방지한다.

Vincent와 Congregation은 해당 앱이 요구하는 iiSharedCanvas 0.11 설치 경로를 prepend_path로 우선한다. 최신 SDK의 전역 검색 경로와 분리하여 다른 ABI의 DLL을 로드하지 않으며 머신 전체 PATH를 프로젝트 명령에 복제하지 않는다. 네이티브 C++ 런타임 검색은 실제 컴파일에 사용한 Qt MinGW 키트를 우선한다.

CTest의 `Windows.NativeRunner`는 실제 Win32 창 생성·비정상 조기 종료·프로세스 종료를 검증하고, workspace runner의 실제 명령 실행·실패 전파·경로 경계·대상 누락 검사를 포함한다. Python 단위 테스트는 실제 HTTP 서버의 응답, 소유 프로세스 정리와 서버 기동 실패 판정도 검증한다.
