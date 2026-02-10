import UIKit
import Flutter
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate {
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
      AppLinks.shared.handleLink(url: url)
      return true
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {

    if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
      if let url = userActivity.webpageURL {
        AppLinks.shared.handleLink(url: url)
        return true
      }
    }

    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

    AppLinks.shared.handleLink(url: url)
    return true
  }
}
