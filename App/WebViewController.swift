import UIKit
import WebKit

/// Loads the Test Mode web files from the app bundle (www-secure/) and plays the part of the native side.
/// The web code talks to native by loading "desmos:<method>/<callbackId>/<argument>" in a hidden iframe.
/// Every call must be answered with ObjC_callback(<callbackId>, <result>), or the web side stops sending more.
/// The self-lock here is a simulation: the alert and banners look like the real ones, but nothing locks the iPad.
final class WebViewController: UIViewController, WKNavigationDelegate {
    private static let bridgeMethods = [
        "hideLoadingScreen", "gaEvent", "openGoogleLogin", "openAppleLogin", "logout",
        "saveCookies", "deleteCookies", "startSingleAppMode", "endSingleAppMode",
        "setWWWSubdomain", "sendSerializedAnalyticsEvent", "sendStoredLogsToDesmos",
    ].joined(separator: " ")

    private var webView: WKWebView!
    private let banner = BannerView()
    private var locked = false
    private var autoUnlock: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.run("if (window.AppBridge && window.AppBridge._resumed) { window.AppBridge._resumed(); }")
        }

        loadWebFiles()
    }

    private func loadWebFiles() {
        guard let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www-secure") else {
            showMissingFilesMessage()
            return
        }
        webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
    }

    private func showMissingFilesMessage() {
        webView.isHidden = true
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 17)
        label.text = "The Test Mode web files are not in this app.\nBuild the demo IPA with tools/make_demo_ipa.py (see README)."
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
        ])
    }

    // MARK: Bridge

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, url.scheme == "desmos" {
            decisionHandler(.cancel)
            handleBridgeCall(url)
            return
        }
        decisionHandler(.allow)
    }

    private func handleBridgeCall(_ url: URL) {
        let rest = String(url.absoluteString.dropFirst("desmos:".count))

        if rest == "loaded" {
            run("window.dcg_aac_active=false;window.dcg_requested_appselflock=false;")
            run("window.ObjC_callback('\(Self.bridgeMethods)');")
            run("window.AppBridge._started('com.testmodedemo.app','7.57.0');")
            return
        }

        let parts = rest.split(separator: "/", maxSplits: 2, omittingEmptySubsequences: false)
        let method = parts.first.map(String.init) ?? ""
        let callbackId = parts.count > 1 ? (Int(parts[1]) ?? -1) : -1

        switch method {
        case "startSingleAppMode": askToLock()
        case "endSingleAppMode": unlock()
        default: break
        }
        run("window.ObjC_callback(\(callbackId), '');")
    }

    private func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: Simulated self-lock

    private func askToLock() {
        guard !locked, presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "Confirm App Self-Lock",
            message: "Test Mode wants to start Assessment Mode. You will be unable to use other apps on iPad until Test Mode ends Assessment Mode. Do you want to allow this?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel) { [weak self] _ in
            self?.run("window.dcg_requested_appselflock=false;window.dcg_aac_active=false;")
        })
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.lock()
        })
        present(alert, animated: true)
    }

    private func lock() {
        locked = true
        run("window.dcg_aac_active=true;")
        banner.show(
            lines: [
                "Your iPad is now locked to Test Mode.",
                "Your iPad will be unlocked when Test Mode ends Assessment Mode, or after 8 hours.",
            ],
            in: view
        )
        autoUnlock?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.unlock() }
        autoUnlock = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8 * 3600, execute: work)
    }

    private func unlock() {
        autoUnlock?.cancel()
        autoUnlock = nil
        run("window.dcg_aac_active=false;")
        guard locked else { return }
        locked = false
        banner.show(lines: ["Your iPad is no longer locked to Test Mode."], in: view)
    }
}
