import UIKit
import WebKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = BrowserViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class BrowserViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardGestures = true
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 本地页面里的 http/https 外链（各路径的官网）交给系统 Safari 打开
        webView.configuration.userContentController.add(self, name: "extlink")

        if let url = Self.indexURL {
            webView.loadFileURL(url, allowingReadAccessTo: Self.docsURL)
        }
    }

    private static var docsURL: URL { Bundle.main.resourceURL! }

    private static var indexURL: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("www/index.html")
    }

    // 外部链接一律丢给 Safari，避免在壳里加载失败
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           url.isFileURL == false {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == "extlink", let urlStr = message.body as? String,
           let url = URL(string: urlStr), url.scheme?.hasPrefix("http") == true {
            UIApplication.shared.open(url)
        }
    }
}
