import Flutter
import UIKit
import receive_sharing_intent

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    // Give shared-media URLs to receive_sharing_intent before other URL plugins.
    _ = ReceiveSharingIntentPlugin.instance.scene(
      scene,
      willConnectTo: session,
      options: connectionOptions
    )
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Shared-media URLs belong to the share extension. All other URLs continue
    // through FlutterSceneDelegate to plugins such as app_links.
    if ReceiveSharingIntentPlugin.instance.scene(scene, openURLContexts: URLContexts) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
