import UIKit
import WebKit

@main
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

final class BrowserViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var titleLabel: UILabel!
    private var backButton: UIBarButtonItem!
    private var forwardButton: UIBarButtonItem!
    private var reloadButton: UIBarButtonItem!
    private var safariButton: UIBarButtonItem!
    private var refreshControl = UIRefreshControl()

    // MARK: - View setup

    override func loadView() {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.isOpaque = true
        // iOS 16+：内容不穿到灵动岛/状态栏下面，交给导航条
        if #available(iOS 16.4, *) {
            webView.underPageBackgroundColor = .systemBackground
        }
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupProgress()
        setupPullToRefresh()

        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoForward", options: .new, context: nil)

        webView.configuration.userContentController.add(self, name: "extlink")

        if let url = Bundle.main.resourceURL?.appendingPathComponent("www/index.html") {
            webView.loadFileURL(url, allowingReadAccessTo: Bundle.main.resourceURL!)
        }
    }

    private func setupNavigationBar() {
        titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"), style: .plain, target: self,
            action: #selector(goBack))
        forwardButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"), style: .plain, target: self,
            action: #selector(goForward))
        reloadButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self,
            action: #selector(reloadPage))
        safariButton = UIBarButtonItem(
            image: UIImage(systemName: "safari"), style: .plain, target: self,
            action: #selector(openInSafari))
        safariButton.isEnabled = false

        backButton.isEnabled = false
        forwardButton.isEnabled = false

        navigationItem.leftBarButtonItems = [backButton, forwardButton]
        navigationItem.rightBarButtonItems = [safariButton, reloadButton]
        navigationItem.titleView = titleLabel

        let navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = .systemBackground
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(navBar)
        container.addSubview(webView)
        view = container

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBar.topAnchor.constraint(equalTo: container.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        // 把 statusBar 从白改成跟随系统（导航条同色，视觉上连续）
        navBar.isTranslucent = false
    }

    private func setupProgress() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true
        progressView.tintColor = .systemBlue
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])
    }

    private func setupPullToRefresh() {
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
    }

    // MARK: - Actions

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }

    @objc private func reloadPage() {
        webView.reload()
    }

    @objc private func didPullToRefresh() {
        webView.reload()
    }

    @objc private func openInSafari() {
        guard let url = webView.url else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - KVO

    override func observeValue(
        forKeyPath keyPath: String?, of object: Any?,
        change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?
    ) {
        DispatchQueue.main.async {
            switch keyPath {
            case "estimatedProgress":
                let p = Float(self.webView.estimatedProgress)
                self.progressView.isHidden = p >= 1.0
                self.progressView.setProgress(p, animated: true)
            case "title":
                self.titleLabel.text = self.webView.title
            case "canGoBack":
                self.backButton.isEnabled = self.webView.canGoBack
            case "canGoForward":
                self.forwardButton.isEnabled = self.webView.canGoForward
            default:
                break
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // 站内的页面跳转（index/student/nomad/hk 之间）允许；
        // 真正的 http/https 外链（各路径官网）交给系统 Safari
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           !url.isFileURL {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        progressView.isHidden = true
        progressView.setProgress(0, animated: false)
        safariButton.isEnabled = false  // 本地页面没有对应网络 URL
        syncPageState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
        progressView.isHidden = true
    }

    private func syncPageState() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        titleLabel.text = webView.title ?? "润学导航"
    }

    // MARK: - WKScriptMessageHandler

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
