import SwiftUI
import UIKit
import WebKit

/// 웹뷰 셸 — 방꾸 웹(PC·모바일과 같은 주소)을 띄운다. 화면·기능은 웹에서 배포하므로 앱 업데이트 없이 바뀐다.
/// 앱이 맡는 건 웹으로 못 하는 최소한(공유 시트·클립보드·햅틱·나침반 권한)과 오프라인 안내뿐.
struct BangkkuWebView: UIViewRepresentable {
    /// 띄울 웹 주소. Info.plist의 BangkkuWebURL로 바꿀 수 있다 (호스트는 WKAppBoundDomains에도 등록해야 함)
    static let webURL: URL = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "BangkkuWebURL") as? String, let u = URL(string: s) { return u }
        return URL(string: "https://patrickjane7121.github.io/bangkku/")!
    }()
    static var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // localStorage(저장한 공간·사주 정보)를 앱에 영구 보관
        config.limitsNavigationsToAppBoundDomains = true   // 앱 바운드 도메인에서만 서비스 워커(오프라인 캐시)가 동작
        config.applicationNameForUserAgent = "BangkkuApp/\(Self.appVersion)"   // 웹이 앱 안인지 알 수 있게
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []

        let ucc = config.userContentController
        ucc.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "share")
        ucc.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "copy")
        ucc.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "haptic")
        ucc.addUserScript(WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: Self.appCSSJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // 페이지가 env(safe-area-inset-*)로 직접 처리
        webView.scrollView.bounces = false
        webView.scrollView.keyboardDismissMode = .interactive
        context.coordinator.webView = webView
        context.coordinator.start()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - JS 브리지

    /// navigator.share / navigator.clipboard.writeText 를 네이티브로 연결
    private static let bridgeJS = """
    (function(){
      var h = window.webkit && window.webkit.messageHandlers;
      if (!h) return;
      try {
        Object.defineProperty(navigator, 'share', {configurable: true, value: function(data){
          data = data || {};
          return h.share.postMessage({title: String(data.title || ''), text: String(data.text || ''), url: String(data.url || '')})
            .then(function(ok){ if (!ok) throw new DOMException('Share canceled', 'AbortError'); });
        }});
        Object.defineProperty(navigator, 'clipboard', {configurable: true, value: {
          writeText: function(t){ return h.copy.postMessage(String(t)).then(function(){}); }
        }});
      } catch (e) {}
    })();
    """

    /// 앱처럼 느껴지도록 길게 누르기 메뉴·텍스트 선택만 끈다 (입력창은 유지)
    private static let appCSSJS = """
    (function(){
      var s = document.createElement('style');
      s.textContent = 'body{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}' +
        'input,textarea,select{-webkit-user-select:text;user-select:text}';
      document.head.appendChild(s);
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        private let impact = UIImpactFeedbackGenerator(style: .light)

        /// 예전(앱 내장 웹) 데이터를 웹 쪽 저장소로 옮길 준비를 한 뒤 웹 주소를 연다
        func start() {
            LegacyStorage.prepare { [weak self] json in
                guard let self, let webView = self.webView else { return }
                if let json {
                    webView.configuration.userContentController.addUserScript(
                        WKUserScript(source: LegacyStorage.seedJS(json), injectionTime: .atDocumentStart, forMainFrameOnly: true))
                }
                self.loadRemote()
            }
        }

        func loadRemote() {
            webView?.load(URLRequest(url: BangkkuWebView.webURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 20))
        }

        /// 인터넷이 없고 저장된 버전도 없을 때의 안내 화면 (번들 offline.html)
        private func showOffline() {
            guard let webView, let file = Bundle.main.url(forResource: "offline", withExtension: "html"),
                  var comps = URLComponents(url: file, resolvingAgainstBaseURL: false) else { return }
            comps.queryItems = [URLQueryItem(name: "u", value: BangkkuWebView.webURL.absoluteString)]
            if let url = comps.url { webView.loadFileURL(url, allowingReadAccessTo: file.deletingLastPathComponent()) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let e = error as NSError
            if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
            showOffline()
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            switch message.name {
            case "haptic":
                impact.impactOccurred()
                impact.prepare()
                replyHandler(true, nil)
            case "copy":
                UIPasteboard.general.string = message.body as? String ?? ""
                replyHandler(true, nil)
            case "share":
                let body = message.body as? [String: Any] ?? [:]
                var items: [Any] = []
                if let text = body["text"] as? String, !text.isEmpty { items.append(text) }
                if let s = body["url"] as? String, let url = URL(string: s), !s.isEmpty { items.append(url) }
                presentShare(items: items, replyHandler: replyHandler)
            default:
                replyHandler(nil, "unknown handler")
            }
        }

        private func presentShare(items: [Any], replyHandler: @escaping (Any?, String?) -> Void) {
            guard !items.isEmpty, let webView, let presenter = webView.window?.rootViewController?.topMost else {
                replyHandler(false, nil)
                return
            }
            let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
            vc.completionWithItemsHandler = { _, completed, _, _ in replyHandler(completed, nil) }
            if let pop = vc.popoverPresentationController {       // iPad
                pop.sourceView = webView
                pop.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.maxY - 80, width: 1, height: 1)
                pop.permittedArrowDirections = .down
            }
            presenter.present(vc, animated: true)
        }

        // 방꾸 웹(같은 호스트)과 오프라인 안내 파일만 앱 안에서 열고, 외부 링크·새 창은 Safari로 넘긴다
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
            let inApp = url.isFileURL || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data"
                || url.host == BangkkuWebView.webURL.host
            if inApp && navigationAction.targetFrame != nil { return decisionHandler(.allow) }
            if !inApp || navigationAction.targetFrame == nil { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }

        // 웹 콘텐츠 프로세스가 종료되면 다시 불러온다 (저장 데이터는 localStorage에 남아 있음)
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        // 방위 설정의 '나침반' 버튼은 사용자가 직접 누를 때만 요청하므로 바로 허용
        func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let presenter = webView.window?.rootViewController?.topMost else { return completionHandler() }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let presenter = webView.window?.rootViewController?.topMost else { return completionHandler(false) }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
            presenter.present(alert, animated: true)
        }
    }
}

/// 예전 버전(번들 안 웹, file:// 저장소)에 남은 방꾸 데이터를 한 번 읽어 두고,
/// 웹 주소 쪽 저장소가 비어 있으면 그대로 채워 넣는다. 한 번 옮기면 다시 하지 않음(bk_legacy_done 표시)
enum LegacyStorage {
    private static let checkedKey = "legacyStorageChecked", dataKey = "legacyStorageJSON"
    private static var reader: Reader?

    static func prepare(_ done: @escaping (String?) -> Void) {
        let d = UserDefaults.standard
        if d.bool(forKey: checkedKey) { return done(d.string(forKey: dataKey)) }
        guard let file = Bundle.main.url(forResource: "offline", withExtension: "html") else {
            d.set(true, forKey: checkedKey); return done(nil)
        }
        let r = Reader { json in
            if let json, json != "{}" { d.set(json, forKey: dataKey) }
            d.set(true, forKey: checkedKey)
            reader = nil
            done(d.string(forKey: dataKey))
        }
        reader = r
        r.read(file)
    }

    static func seedJS(_ json: String) -> String {
        """
        (function(){try{
          if(localStorage.getItem('bk_legacy_done')) return;
          var d=\(json), has=false;
          for(var i=0;i<localStorage.length;i++){ if(localStorage.key(i).indexOf('bangku.')===0){has=true;break;} }
          if(!has){ for(var k in d){ localStorage.setItem(k,d[k]); } }
          localStorage.setItem('bk_legacy_done','1');
        }catch(e){}})();
        """
    }

    /// 숨은 웹뷰로 file:// 저장소를 읽는다 (최대 3초)
    final class Reader: NSObject, WKNavigationDelegate {
        private var web: WKWebView?
        private var finish: ((String?) -> Void)?
        init(_ finish: @escaping (String?) -> Void) { self.finish = finish }

        func read(_ file: URL) {
            let cfg = WKWebViewConfiguration()
            cfg.websiteDataStore = .default()
            let w = WKWebView(frame: .zero, configuration: cfg)
            w.navigationDelegate = self
            web = w
            w.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.done(nil) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = "(function(){var o={};for(var i=0;i<localStorage.length;i++){var k=localStorage.key(i);if(k.indexOf('bangku.')===0)o[k]=localStorage.getItem(k);}return JSON.stringify(o);})()"
            webView.evaluateJavaScript(js) { [weak self] result, _ in self?.done(result as? String) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { done(nil) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { done(nil) }

        private func done(_ json: String?) {
            guard let f = finish else { return }
            finish = nil
            web = nil
            f(json)
        }
    }
}

private extension UIViewController {
    var topMost: UIViewController {
        presentedViewController?.topMost ?? self
    }
}
