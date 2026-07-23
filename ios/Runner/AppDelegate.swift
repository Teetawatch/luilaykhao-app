import Flutter
import GoogleMaps
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // คีย์มาจาก ios/Flutter/Secrets.xcconfig (ไม่เข้า git) ผ่าน Info.plist
    // ถ้ายังไม่ได้ตั้งคีย์ก็ข้ามไป แอปจะใช้แผนที่ OSM แทนเอง
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !key.isEmpty
    {
      GMSServices.provideAPIKey(key)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBadgeChannel(with: engineBridge.pluginRegistry)
  }

  private func registerBadgeChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "LuilaykhaoBadgeChannel") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "luilaykhao/badge",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadgeCount":
        let args = call.arguments as? [String: Any]
        let count = (args?["count"] as? Int) ?? 0
        DispatchQueue.main.async {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
              if let error = error {
                result(
                  FlutterError(
                    code: "badge_error",
                    message: error.localizedDescription,
                    details: nil
                  )
                )
              } else {
                result(nil)
              }
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = count
            result(nil)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
