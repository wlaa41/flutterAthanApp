// Athan alarms on iPhone, through Apple's AlarmKit (iOS 26 and later).
//
// An athan that rings as an alarm takes over the Lock Screen with Stop and
// Snooze, and rings in Silent mode and through a Focus. iOS draws that screen.
//
// This file is compiled into the app and into the AthanAlarm extension. The
// extension draws the alarm in the Dynamic Island and on the Lock Screen once
// the first full-screen alert is gone; its buttons run the two intents below,
// which iOS performs inside the app.

import Foundation

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI

/// Travels with every athan alarm to its Live Activity.
@available(iOS 26.0, *)
struct AthanAlarmData: AlarmMetadata {
  var title: String
}

@available(iOS 26.0, *)
enum AthanAlarms {
  /// A prayer reminder's alarm carries the reminder's number in its
  /// identifier, so the same reminder is never armed twice.
  static let planPrefix = "A7A40000-0000-4000-8000-"
  /// "Try the alarm" in Settings.
  static let testPrefix = "A7A47E57"
  /// What is armed under each identifier: "time|snooze|sound|title".
  static let storeKey = "athan_alarmkit_v1"
  static let tint = Color(red: 0.09, green: 0.55, blue: 0.42)

  static func planID(_ number: Int) -> UUID? {
    guard number >= 0 else { return nil }
    return UUID(uuidString: planPrefix + String(format: "%012llX", Int64(number)))
  }

  static func planNumber(_ id: UUID) -> Int? {
    let text = id.uuidString
    guard text.hasPrefix(planPrefix) else { return nil }
    return Int(String(text.dropFirst(planPrefix.count)), radix: 16)
  }

  static func testID() -> UUID {
    let random = UUID().uuidString
    return UUID(uuidString: testPrefix + String(random.dropFirst(testPrefix.count))) ?? UUID()
  }

  static func store() -> [String: String] {
    UserDefaults.standard.dictionary(forKey: storeKey) as? [String: String] ?? [:]
  }

  static func save(_ store: [String: String]) {
    UserDefaults.standard.set(store, forKey: storeKey)
  }

  static func signature(_ ms: Int64, _ title: String, _ sound: String, _ snoozeMinutes: Int) -> String {
    "\(ms)|\(snoozeMinutes)|\(sound)|\(title)"
  }

  static func title(_ signature: String?) -> String {
    let parts = (signature ?? "").split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
    return parts.count == 4 && !parts[3].isEmpty ? String(parts[3]) : "Athan"
  }

  static var stateName: String {
    switch AlarmManager.shared.authorizationState {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }

  static func requestAccess() async {
    _ = try? await AlarmManager.shared.requestAuthorization()
  }

  /// One alarm at [date]. Snooze is AlarmKit's own: the alarm counts down for
  /// [snoozeMinutes] and rings again, with no code of ours in between.
  static func schedule(id: UUID, at date: Date, title: String, sound: String, snoozeMinutes: Int) async throws {
    let minutes = max(1, min(snoozeMinutes, 60))
    let alert = AlarmPresentation.Alert(
      title: LocalizedStringResource(stringLiteral: title),
      stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
      secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz"),
      secondaryButtonBehavior: .countdown)
    // The countdown is the snooze. Nothing here can pause it, but AlarmKit's
    // own sample gives a paused state whenever there is a countdown.
    let presentation = AlarmPresentation(
      alert: alert,
      countdown: AlarmPresentation.Countdown(title: LocalizedStringResource(stringLiteral: title)),
      paused: AlarmPresentation.Paused(
        title: LocalizedStringResource(stringLiteral: title),
        resumeButton: AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.circle")))
    let attributes = AlarmAttributes<AthanAlarmData>(
      presentation: presentation,
      metadata: AthanAlarmData(title: title),
      tintColor: tint)
    // The name carries its extension, and the file sits in the app bundle.
    let alertSound: AlertConfiguration.AlertSound = sound.isEmpty ? .default : .named(sound)
    let configuration = AlarmManager.AlarmConfiguration<AthanAlarmData>(
      countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval(minutes * 60)),
      schedule: .fixed(date),
      attributes: attributes,
      stopIntent: nil,
      secondaryIntent: nil,
      sound: alertSound)
    _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
  }

  private struct Wanted {
    let number: Int
    let id: UUID
    let date: Date
    let title: String
    let sound: String
    let signature: String
  }

  /// Makes the armed prayer alarms match [events]. An alarm that is already
  /// armed and unchanged is left alone, and one that is ringing or snoozed is
  /// never touched. Stops at the first alarm iOS refuses; the app keeps those
  /// reminders as notifications.
  static func replace(_ events: [[String: Any]], snoozeMinutes: Int) async -> [String: Any] {
    let manager = AlarmManager.shared
    var saved = store()
    var wanted: [Wanted] = []
    for event in events {
      guard let number = (event["id"] as? NSNumber)?.intValue,
            let ms = (event["time"] as? NSNumber)?.int64Value,
            let id = planID(number) else { continue }
      let title = event["title"] as? String ?? "Athan"
      let sound = event["sound"] as? String ?? ""
      wanted.append(Wanted(
        number: number,
        id: id,
        date: Date(timeIntervalSince1970: Double(ms) / 1000),
        title: title,
        sound: sound,
        signature: signature(ms, title, sound, snoozeMinutes)))
    }
    wanted.sort { $0.date < $1.date }
    var signatures: [String: String] = [:]
    for item in wanted { signatures[item.id.uuidString] = item.signature }

    var kept = Set<UUID>()
    var busy = Set<UUID>()
    for alarm in (try? manager.alarms) ?? [] {
      guard planNumber(alarm.id) != nil else { continue }
      let key = alarm.id.uuidString
      switch alarm.state {
      case .scheduled:
        if let signature = signatures[key], saved[key] == signature {
          kept.insert(alarm.id)
        } else {
          try? manager.cancel(id: alarm.id)
          saved[key] = nil
        }
      default:
        busy.insert(alarm.id)
      }
    }

    var armed: [Int] = []
    var failure = ""
    for item in wanted {
      if kept.contains(item.id) {
        armed.append(item.number)
        continue
      }
      if busy.contains(item.id) { continue }
      do {
        try await schedule(
          id: item.id, at: item.date, title: item.title, sound: item.sound,
          snoozeMinutes: snoozeMinutes)
        saved[item.id.uuidString] = item.signature
        armed.append(item.number)
      } catch {
        failure = String(describing: error)
        break
      }
    }

    // Forget what is no longer on the phone.
    var alive = Set<String>()
    for alarm in (try? manager.alarms) ?? [] { alive.insert(alarm.id.uuidString) }
    saved = saved.filter { alive.contains($0.key) }
    save(saved)

    var answer = status()
    answer["armed"] = armed
    answer["error"] = failure
    return answer
  }

  /// One alarm at [ms], to try the alarm screen.
  static func test(at ms: Int64, title: String, sound: String, snoozeMinutes: Int) async -> [String: Any] {
    let id = testID()
    let date = Date(timeIntervalSince1970: Double(ms) / 1000)
    var failure = ""
    do {
      try await schedule(id: id, at: date, title: title, sound: sound, snoozeMinutes: snoozeMinutes)
      var saved = store()
      saved[id.uuidString] = signature(Int64(date.timeIntervalSince1970 * 1000), title, sound, snoozeMinutes)
      save(saved)
    } catch {
      failure = String(describing: error)
    }
    var answer = status()
    answer["error"] = failure
    return answer
  }

  /// Stops a ringing alarm. A snoozed or waiting one is taken off instead.
  static func stop(_ text: String) {
    guard let id = UUID(uuidString: text) else { return }
    do {
      try AlarmManager.shared.stop(id: id)
    } catch {
      try? AlarmManager.shared.cancel(id: id)
    }
  }

  /// Snoozes a ringing alarm for the minutes it was armed with.
  static func snooze(_ text: String) {
    guard let id = UUID(uuidString: text) else { return }
    try? AlarmManager.shared.countdown(id: id)
  }

  static func cancelSnoozed() {
    for alarm in (try? AlarmManager.shared.alarms) ?? [] {
      switch alarm.state {
      case .countdown, .paused: stop(alarm.id.uuidString)
      default: break
      }
    }
  }

  /// Takes every waiting or snoozed alarm off. One that is ringing is left to
  /// the person holding the phone.
  static func cancelAll() {
    for alarm in (try? AlarmManager.shared.alarms) ?? [] {
      switch alarm.state {
      case .alerting: break
      case .scheduled: try? AlarmManager.shared.cancel(id: alarm.id)
      default: stop(alarm.id.uuidString)
      }
    }
    save([:])
  }

  static func status() -> [String: Any] {
    var scheduled = 0
    var snoozed = 0
    var ringing: [[String: Any]] = []
    let saved = store()
    for alarm in (try? AlarmManager.shared.alarms) ?? [] {
      let key = alarm.id.uuidString
      switch alarm.state {
      case .scheduled:
        if planNumber(alarm.id) != nil { scheduled += 1 }
      case .countdown, .paused:
        snoozed += 1
      case .alerting:
        ringing.append(["id": key, "title": title(saved[key])])
      @unknown default:
        break
      }
    }
    return [
      "supported": true,
      "state": stateName,
      "scheduled": scheduled,
      "snoozed": snoozed,
      "ringing": ringing,
    ]
  }
}

/// Stop, on the Live Activity. The first full-screen alert has its own Stop.
@available(iOS 26.0, *)
struct AthanStopIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Stop the athan"
  static var description = IntentDescription("Stops the athan alarm that is ringing or snoozed.")
  static var isDiscoverable: Bool = false

  @Parameter(title: "Alarm")
  var alarmID: String

  init() {
    self.alarmID = ""
  }

  init(alarmID: String) {
    self.alarmID = alarmID
  }

  func perform() async throws -> some IntentResult {
    AthanAlarms.stop(alarmID)
    return .result()
  }
}

/// Snooze, on the Live Activity.
@available(iOS 26.0, *)
struct AthanSnoozeIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Snooze the athan"
  static var description = IntentDescription("Snoozes the athan alarm that is ringing.")
  static var isDiscoverable: Bool = false

  @Parameter(title: "Alarm")
  var alarmID: String

  init() {
    self.alarmID = ""
  }

  init(alarmID: String) {
    self.alarmID = alarmID
  }

  func perform() async throws -> some IntentResult {
    AthanAlarms.snooze(alarmID)
    return .result()
  }
}
#endif
