import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: TregoNativeRootView())
        window.makeKeyAndVisible()
        self.window = window

        if let userInfo = connectionOptions.notificationResponse?.notification.request.content.userInfo,
           !userInfo.isEmpty {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("TregoRemoteNotificationOpened"),
                    object: nil,
                    userInfo: userInfo
                )
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
