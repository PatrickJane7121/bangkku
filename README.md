# 방꾸 (bangkku)

내 방의 기운을 바꾸는 공간 진단 — 웹(PC·모바일) + iOS 앱.

사주(만세력) 계산 → 고민 선택 → 방 모양 그리기 → 현재 가구 배치 → 풍수 규칙 진단 리포트·이상 배치 제안·평면도/3D 뷰까지.

## 구조 — 웹뷰 방식

화면과 기능은 **웹 한 벌**(`index.html`)로 만들고, PC·모바일 브라우저와 iOS 앱이 같은 주소를 띄웁니다.
웹만 배포하면 **앱 업데이트 없이** 앱에도 바로 반영돼요.

```
index.html                  방꾸 본체 (HTML/CSS/JS 한 파일) — 화면·기능은 전부 여기서 고쳐요
sw.js                       서비스 워커: 최신 우선 + 오프라인 캐시
manifest.webmanifest, icons/  PC·모바일 브라우저에서 '앱 설치'(PWA)용
Bangkku.xcodeproj           iOS 앱 셸 (iOS 15+, iPhone·iPad)
Bangkku/
  BangkkuApp.swift          SwiftUI 앱 진입점
  BangkkuWebView.swift      WKWebView 셸 — 웹 주소 열기 + 네이티브 브리지 + 오프라인 안내 + 예전 데이터 이관
  Web/offline.html          처음 실행인데 인터넷이 없을 때 보여 줄 안내 화면
  Assets.xcassets           앱 아이콘, 런치 화면 색상
  Info.plist                웹 주소(BangkkuWebURL), 앱 바운드 도메인(WKAppBoundDomains)
```

### 앱(셸)이 맡는 것 — 최소한만
- 웹 주소 열기 (`Info.plist`의 `BangkkuWebURL`, 기본값 `https://patrickjane7121.github.io/bangkku/`)
- 웹으로는 안 되는 기능: iOS 공유 시트, 클립보드, 햅틱, 나침반(방향 센서) 권한
- 인터넷이 없고 저장된 버전도 없을 때 안내 화면
- 예전 버전(웹이 앱 안에 들어 있던 방식)에 저장된 데이터를 첫 실행 때 웹 쪽으로 옮기기

웹은 `navigator.userAgent`의 `BangkkuApp/버전`으로 앱 안인지 알 수 있어요(내 정보 화면에 표시).

### 업데이트 흐름
1. `index.html`을 고쳐 `main`에 올립니다 (`WEB_VERSION`도 올려 주세요).
2. GitHub Pages가 1~2분 안에 배포합니다.
3. PC·모바일 브라우저와 iOS 앱 모두 다음 실행부터 새 버전이 열려요. 온라인이면 항상 최신을 받아 오고(network-first), 오프라인이면 마지막으로 받은 버전이 열립니다.

앱 업데이트(App Store 제출)가 필요한 경우는 셸을 바꿀 때뿐이에요: 네이티브 기능 추가, 웹 주소·도메인 변경, 아이콘 변경 등.
웹 주소의 호스트를 바꾸면 `WKAppBoundDomains`에도 같이 넣어 주세요(서비스 워커·스크립트 주입 조건).

## 실행

### 웹 (GitHub Pages)
1. 저장소 **Settings → Pages**에서 Source를 **Deploy from a branch**, Branch를 `main` / `/(root)`로 저장합니다.
2. `https://<사용자명>.github.io/<저장소명>/` 주소로 열립니다. PC Chrome·Edge나 모바일 브라우저에서 '앱 설치/홈 화면에 추가'도 돼요.

### iOS 앱
1. Mac에서 `Bangkku.xcodeproj`를 Xcode 15 이상으로 엽니다.
2. 타깃 **Bangkku → Signing & Capabilities**에서 Team을 선택합니다 (필요하면 Bundle Identifier `com.bangkku.app`을 본인 것으로).
3. 시뮬레이터나 iPhone을 고르고 ▶︎ Run. 첫 실행에는 인터넷이 필요해요.

App Store 배포는 Product → Archive 후 Organizer에서 업로드합니다 (Apple Developer Program 가입 필요).

## 데이터
저장한 공간과 사주 정보는 각 기기·브라우저의 localStorage에 보관돼요 (앱과 PC는 서로 따로 저장). 기기 간 동기화가 필요하면 로그인·서버 저장을 추가해야 해요.

## 콘셉트 뷰 (실사풍 레퍼런스)
종합 리포트의 '이 배치가 완성된 모습'은 내장 3D 무드 렌더로 바로 동작하고, 실사 사진 라이브러리나 AI 이미지 생성 서버를 연결할 수 있어요. 구조와 API 형식은 [`docs/CONCEPT_VIEW.md`](docs/CONCEPT_VIEW.md)를 보세요.
