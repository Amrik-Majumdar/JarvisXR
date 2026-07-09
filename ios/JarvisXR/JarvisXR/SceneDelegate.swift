import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: JarvisRootViewController())
        window.tintColor = JarvisTheme.accent
        self.window = window
        window.makeKeyAndVisible()
        if let url = connectionOptions.urlContexts.first?.url {
            DispatchQueue.main.async {
                _ = JarvisDeepLinkRouter.handle(url)
            }
        }
        if let pending = JarvisPendingIntentStore.consumeAction() {
            DispatchQueue.main.async {
                JarvisDeepLinkRouter.post(pending)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        _ = JarvisDeepLinkRouter.handle(url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let pending = JarvisPendingIntentStore.consumeAction() {
            JarvisDeepLinkRouter.post(pending)
        }
    }
}
