import SwiftUI
import UIKit
import WebKit

/// 번들에 포함된 방꾸 웹앱(Web/index.html)을 띄우는 WKWebView.
/// 공유·복사는 네이티브 기능으로 연결한다.
struct BangkkuWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // localStorage(저장한 공간·사주 정보)를 앱에 영구 보관
        config.allowsInlineMediaPlayback = true
        config.dataDetectorTypes = []

        let ucc = config.userContentController
        ucc.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "share")
        ucc.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "copy")
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

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
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

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage,
                                   replyHandler: @escaping (Any?, String?) -> Void) {
            switch message.name {
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

        // 번들 안의 파일만 앱 안에서 열고, 외부 링크는 Safari로 넘긴다
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
            if url.isFileURL || url.scheme == "about" { return decisionHandler(.allow) }
            UIApplication.shared.open(url)
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

private extension UIViewController {
    var topMost: UIViewController {
        presentedViewController?.topMost ?? self
    }
}
