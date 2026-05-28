import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    static var shortcutAction: String? = nil

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        AppDelegate.shortcutAction = shortcutItem.type
        completionHandler(true)
    }
}
