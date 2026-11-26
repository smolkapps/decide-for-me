import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var versionEnforcerChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "org.smolkin.version_enforcer",
        binaryMessenger: controller.binaryMessenger
      )
      versionEnforcerChannel = channel
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getAppVersion":
          let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
          result(version)
        case "openUrl":
          if let args = call.arguments as? [String: Any],
             let raw = args["url"] as? String,
             let url = URL(string: raw) {
            DispatchQueue.main.async {
              UIApplication.shared.open(url, options: [:]) { opened in
                result(opened)
              }
            }
          } else {
            result(false)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
