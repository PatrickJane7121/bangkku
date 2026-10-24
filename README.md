# 방꾸 (bangkku)

내 방의 기운을 바꾸는 공간 진단 — iOS 앱.

사주(만세력) 계산 → 고민 선택 → 방 모양 그리기 → 현재 가구 배치 → 풍수 규칙(SRC-001~078) 진단 리포트·이상 배치 제안·평면도/3D 뷰까지,
웹 프로토타입과 똑같이 동작하는 앱입니다.

## 구조

```
Bangkku.xcodeproj           Xcode 프로젝트 (iOS 15+, iPhone·iPad)
Bangkku/
  BangkkuApp.swift          SwiftUI 앱 진입점
  BangkkuWebView.swift      WKWebView 셸 + 네이티브 브리지(공유 시트, 클립보드)
  Web/index.html            방꾸 앱 본체 (HTML/CSS/JS, 오프라인 동작)
  Assets.xcassets           앱 아이콘, 런치 화면 색상
  Info.plist                런치 화면 설정
```

- 앱 화면·로직은 `Bangkku/Web/index.html` 하나에 들어 있어요. 이 파일을 고치면 앱에 그대로 반영됩니다.
- 저장한 공간과 사주 정보는 앱 안의 localStorage에 보관돼 앱을 껐다 켜도 유지돼요.
- `공유하기`는 iOS 공유 시트, `리포트 복사`는 iOS 클립보드로 연결돼요.
- 인터넷 연결 없이 동작해요.

## 실행

1. Mac에서 `Bangkku.xcodeproj`를 Xcode 15 이상으로 엽니다.
2. 타깃 **Bangkku → Signing & Capabilities**에서 Team을 선택합니다
   (필요하면 Bundle Identifier `com.bangkku.app`을 본인 것으로 바꾸세요).
3. 시뮬레이터나 연결한 iPhone을 고르고 ▶︎ Run.

App Store 배포는 Product → Archive 후 Organizer에서 업로드하면 됩니다 (Apple Developer Program 가입 필요).
