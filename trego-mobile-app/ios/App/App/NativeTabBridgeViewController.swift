import UIKit
import Capacitor
import SwiftUI
import WebKit

final class NativeTabBridgeViewController: CAPBridgeViewController, WKScriptMessageHandler {
    private static let tabStateMessageName = "tregoTabState"

    private let tabBarModel = NativeTabBarModel()
    private lazy var scriptMessageProxy = WeakScriptMessageProxy(delegate: self)
    private var hostingController: UIHostingController<NativeTabBarOverlay>?
    private weak var observedWebView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        installNativeTabBarOverlayIfNeeded()
        configureBridgeIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureBridgeIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let hostingView = hostingController?.view {
            view.bringSubviewToFront(hostingView)
        }
    }

    deinit {
        observedWebView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.tabStateMessageName)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.tabStateMessageName else {
            return
        }

        guard let body = message.body as? [String: Any] else {
            return
        }

        if let showTabBar = body["showTabBar"] as? Bool {
            tabBarModel.isVisible = showTabBar
            hostingController?.view.isUserInteractionEnabled = showTabBar
        }

        if let selectedTab = body["selectedTab"] as? String,
           let tab = LiquidGlassTab(rawValue: selectedTab),
           !selectedTab.isEmpty {
            tabBarModel.selectedTab = tab
        }

        if let badgePayload = body["badges"] as? [String: Any] {
            var nextBadges: [LiquidGlassTab: String] = [:]
            for tab in LiquidGlassTab.allCases {
                if let badge = badgePayload[tab.rawValue] as? String, !badge.isEmpty {
                    nextBadges[tab] = badge
                }
            }
            tabBarModel.badges = nextBadges
        }
    }

    private func installNativeTabBarOverlayIfNeeded() {
        guard hostingController == nil else {
            if let hostingView = hostingController?.view {
                view.bringSubviewToFront(hostingView)
            }
            return
        }

        let overlay = NativeTabBarOverlay(model: tabBarModel) { [weak self] tab in
            self?.navigateToTab(tab)
        }
        let host = UIHostingController(rootView: overlay)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        host.view.isUserInteractionEnabled = false
        hostingController = host
    }

    private func configureBridgeIfNeeded(retriesRemaining: Int = 10) {
        guard let webView = findWebView(in: view) else {
            guard retriesRemaining > 0 else {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.configureBridgeIfNeeded(retriesRemaining: retriesRemaining - 1)
            }
            return
        }

        if observedWebView !== webView {
            observedWebView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.tabStateMessageName)
            webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.tabStateMessageName)
            webView.configuration.userContentController.add(scriptMessageProxy, name: Self.tabStateMessageName)
            observedWebView = webView
        }

        injectNativeShellMarker(into: webView)
    }

    private func injectNativeShellMarker(into webView: WKWebView) {
        let script = """
        (function() {
          document.documentElement.dataset.nativeIosSwiftuiTabbar = "1";
          document.body.dataset.nativeIosSwiftuiTabbar = "1";
          return true;
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func navigateToTab(_ tab: LiquidGlassTab) {
        tabBarModel.selectedTab = tab

        guard let webView = observedWebView ?? findWebView(in: view) else {
            return
        }

        let path = tab.routePath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let script = """
        (function() {
          if (typeof window.__tregoNativeNavigateTo === "function") {
            window.__tregoNativeNavigateTo('\(path)');
            return true;
          }
          window.dispatchEvent(new CustomEvent("trego:native-tab-navigate", { detail: { path: '\(path)' } }));
          return true;
        })();
        """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func findWebView(in view: UIView?) -> WKWebView? {
        guard let view else {
            return nil
        }

        if let webView = view as? WKWebView {
            return webView
        }

        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }

        return nil
    }
}

private final class NativeTabBarModel: ObservableObject {
    @Published var isVisible = false
    @Published var selectedTab: LiquidGlassTab = .home
    @Published var badges: [LiquidGlassTab: String] = [:]
}

private struct NativeTabBarOverlay: View {
    @ObservedObject var model: NativeTabBarModel
    let onSelect: (LiquidGlassTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if model.isVisible {
                LiquidGlassTabBar(
                    selection: Binding(
                        get: { model.selectedTab },
                        set: { model.selectedTab = $0 }
                    ),
                    badges: model.badges,
                    onSelectionChange: onSelect
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.spring(response: 0.38, dampingFraction: 0.88, blendDuration: 0.18), value: model.isVisible)
        .allowsHitTesting(model.isVisible)
    }
}

private final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

private extension LiquidGlassTab {
    var routePath: String {
        switch self {
        case .home:
            return "/tabs/home"
        case .kerko:
            return "/tabs/search"
        case .wishlist:
            return "/tabs/wishlist"
        case .cart:
            return "/tabs/cart"
        case .llogaria:
            return "/tabs/account"
        }
    }
}
