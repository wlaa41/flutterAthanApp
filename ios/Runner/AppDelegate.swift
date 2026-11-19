import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "athan/alarms", binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { call, result in
        if call.method == "appSettings", let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
  }
}

class SceneDelegate: FlutterSceneDelegate {}
