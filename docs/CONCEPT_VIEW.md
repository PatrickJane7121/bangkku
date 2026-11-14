# 콘셉트 뷰 (실사풍 레퍼런스 연동) 구조

종합 리포트의 **03 · Concept View**는 "이 배치가 실제로 완성되면 어떤 분위기일까"를 보여 줍니다.
진단 결과를 **콘셉트 브리프**라는 하나의 데이터로 만들고, 여러 **공급자(provider)**가 그 브리프를 시각화하는 구조입니다.

```
진단 결과 (오행 처방 · 고민 · 방 크기/모양 · 제안 배치)
        │
        ▼
 conceptBrief()  ──►  { style, palette, tips, room, layout[], promptKo, promptEn, negative }
        │
        ├─► local   : 내장 3D 렌더러 무드 모드 + 팔레트 + 스타일 키워드      (항상, 오프라인)
        ├─► curated : 라이선스 확보한 실사 사진 목록(JSON)에서 태그로 골라 보여 줌  (curatedUrl 설정 시)
        └─► ai      : 이미지 생성 서버에 브리프를 보내 실사풍 이미지를 받아 옴      (aiEndpoint 설정 시)
```

- 연동 설정: 루트 `index.html`의 `CONCEPT_CONFIG = {curatedUrl:"", aiEndpoint:""}`
- 아무것도 설정하지 않으면 **local** 만 동작하고, "프롬프트 복사" 버튼으로 브리프를 아무 이미지 생성 AI에나 붙여 넣을 수 있습니다.

## 1. 콘셉트 브리프

| 필드 | 내용 | 출처 |
|---|---|---|
| `style` | 스타일 이름·영문명·태그·팔레트(hex/한글/영문)·무드 문장 | 처방 오행 → `STYLE_BY_EL` (목=내추럴 보태니컬, 화=웜 테라코타, 토=샌드 베이지 미니멀, 금=화이트 모던, 수=딥 블루 라운지) |
| `tips` | 조명 · 패브릭 · 소품 · 배치 | `ADD`(오행 처방), `TWEAK`(고민 보정) |
| `room` | `{w, d, type}` (m, `bed`/`living`/`study`) | 그린 방 |
| `layout[]` | `{type, name, en, zone, zoneEn, x, y, w, d, ang}` — 실제 방위 기준 구역 포함 | 제안 배치(없으면 현재 배치) |
| `promptKo` / `promptEn` / `negative` | 이미지 생성용 문장 | 위 값들을 조합 |

## 2. curated — 실사 레퍼런스 사진 라이브러리

`curatedUrl`에서 아래 형식의 JSON 배열을 받습니다. **사용 허락(라이선스)을 받은 사진만** 넣어 주세요.

```json
[
  { "url": "https://cdn.example.com/refs/nordic-bed-01.jpg",
    "tags": ["natural", "botanical", "wood", "bed"],
    "credit": "Photo by 홍길동",
    "link": "https://example.com/original" }
]
```

- 태그 매칭: 스타일 태그(`style.tags`)가 하나 이상 맞는 사진만, 스타일 3배 + 방 종류·가구 종류 1배로 점수를 매겨 상위 4장을 보여 줍니다.
- 권장 태그: 스타일(`natural botanical wood green linen / warm terracotta mediterranean cozy / japandi minimal beige ceramic / white modern hotel metal / navy blue calm velvet`), 방(`bed living study`), 가구 타입 키(`bed desk sofa x_dresser …`).
- 운영 팁: 처음에는 스타일×방 종류별 5~10장씩(약 150장)으로 시작하고, 정적 JSON을 CDN에 두면 서버 없이 운영할 수 있습니다.

## 3. ai — 실사풍 이미지 생성 서버

앱이 `aiEndpoint`로 `POST`(JSON) 합니다.

```json
{
  "prompt": "Photorealistic interior photograph of a 15 square meter Korean bedroom, ...",
  "prompt_ko": "실사 인테리어 사진, 약 15㎡ 한국 침실, ...",
  "negative_prompt": "cartoon, illustration, distorted furniture, ...",
  "style": "deep blue calm lounge",
  "palette": ["#2E4A66", "#8FA9BF", "#E8E4DC", "#5B5550"],
  "room": { "w": 4.2, "d": 3.6, "type": "bed" },
  "layout": [ { "type": "bed", "en": "queen bed", "zoneEn": "east side", "x": 2.4, "y": 1.2, "w": 1.5, "d": 2.0, "ang": 90 } ],
  "size": "1024x768"
}
```

응답:

```json
{ "image_url": "https://cdn.example.com/renders/ab12.jpg" }
```

- **API 키는 앱에 넣지 말고 서버에만** 두세요. 서버가 이미지 생성 서비스(원하는 모델)를 호출하고, 결과를 저장소(CDN)에 올린 뒤 URL만 돌려주는 구조입니다.
- CORS: 웹(GitHub Pages)과 iOS 앱(파일 출처)에서 호출하므로 `Access-Control-Allow-Origin: *` 응답 헤더가 필요합니다. iOS는 `https`만 허용됩니다.
- 캐시: 앱은 같은 배치(오행·방·가구 위치)의 결과 URL을 `localStorage`의 `bangku.concept.<hash>`에 저장해 다시 요청하지 않습니다(초기화 시 함께 삭제). 서버도 같은 해시로 캐시하면 비용을 줄일 수 있습니다.
- `layout`을 이용하면 배치 도면을 조건으로 쓰는 생성 방식(도면 → 실사 렌더)으로도 확장할 수 있습니다.
- 생성 이미지는 "AI가 만든 참고용 이미지"로 표시합니다.

## 4. 앞으로 확장할 수 있는 것

- 결과 화면(평면도·3D) 탭에도 "분위기" 탭 추가 — 같은 `renderConcept()` 재사용
- 사용자가 고른 실사 사진을 저장된 공간에 함께 보관(무드보드)
- 스타일을 오행 처방 외에 사용자가 직접 고르는 옵션
