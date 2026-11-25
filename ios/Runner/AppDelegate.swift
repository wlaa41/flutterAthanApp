import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterMethodChannel(name: "athan/alarms", binaryMessenger: engineBridge.applicationRegistrar.messenger())
      .setMethodCallHandler { call, result in
        if call.method == "appSettings", let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url); result(nil)
        } else if call.method.hasPrefix("alarmKit") {
          AthanAlarmChannel.handle(call, result: result)
        } else if call.method == "checkTimes" {
          // Only tools/ios_alarm_check.sh sets this: the times its UI test chose.
          result(ProcessInfo.processInfo.environment["ATHAN_ALARM_CHECK_AT"] ?? "")
        } else { result(FlutterMethodNotImplemented) }
      }
  }
}
class SceneDelegate: FlutterSceneDelegate {}

/// Where the app asks for the iPhone's alarms: every "alarmKit…" call. Each
/// one answers with what is armed, snoozed and ringing right now. The alarms
/// themselves live in AthanAlarm/AthanAlarmKit.swift.
enum AthanAlarmChannel {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    if #available(iOS 26.0, *) {
      let method = call.method
      let arguments = call.arguments as? [String: Any] ?? [:]
      Task {
        let answer = await run(method, arguments)
        DispatchQueue.main.async { result(answer) }
      }
      return
    }
    #endif
    // Before iOS 26 there is no alarm screen: athans stay notifications.
    let none: [String: Any] = [
      "supported": false,
      "state": "unsupported",
      "scheduled": 0,
      "snoozed": 0,
      "ringing": [[String: Any]](),
    ]
    result(none)
  }

  #if canImport(AlarmKit)
  @available(iOS 26.0, *)
  static func run(_ method: String, _ arguments: [String: Any]) async -> [String: Any] {
    let id = arguments["id"] as? String ?? ""
    let snoozeMinutes = (arguments["snoozeMinutes"] as? NSNumber)?.intValue ?? 10
    switch method {
    case "alarmKitRequest":
      await AthanAlarms.requestAccess()
    case "alarmKitReplace":
      return await AthanAlarms.replace(
        arguments["events"] as? [[String: Any]] ?? [],
        snoozeMinutes: snoozeMinutes)
    case "alarmKitTest":
      let soon = Int64((Date().timeIntervalSince1970 + 60) * 1000)
      return await AthanAlarms.test(
        at: (arguments["time"] as? NSNumber)?.int64Value ?? soon,
        title: arguments["title"] as? String ?? "Test athan",
        sound: arguments["sound"] as? String ?? "",
        snoozeMinutes: snoozeMinutes)
    case "alarmKitStop":
      AthanAlarms.stop(id)
    case "alarmKitSnooze":
      AthanAlarms.snooze(id)
    case "alarmKitCancelSnooze":
      AthanAlarms.cancelSnoozed()
    case "alarmKitCancelAll":
      AthanAlarms.cancelAll()
    default:
      break
    }
    return AthanAlarms.status()
  }
  #endif
}
