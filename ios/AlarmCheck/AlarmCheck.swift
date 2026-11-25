import XCTest

/// Rings two athan alarms on a simulator and walks through them with nobody
/// at the screen.
///
/// The first rings with the phone in use: open its Live Activity, snooze it,
/// find the snoozed athan on the lock screen and stop it there. The second
/// rings with the phone locked and dark, and is stopped from wherever iOS
/// shows it.
///
/// This file is not part of the app. `tools/ios_alarm_check.sh` adds it to
/// the project as a UI test for one run, builds the app so that it sets the
/// test alarms itself, and keeps a picture of every step. The test names both
/// alarm times when it starts the app, so it knows when to look.
///
/// On some simulators SpringBoard restarts when an alarm tone starts: its tone
/// player calls a method the simulator does not have (ToneLibrary,
/// TLAlertQueuePlayerController), with or without this app. A test loses a
/// SpringBoard it was talking to, and is closed itself if it blocks its main
/// thread through the restart. So this one asks the simulator nothing while
/// an alarm fires: it waits without blocking and looks afterwards. The alarm
/// keeps ringing across a restart. The video of the run has the moment itself.
///
/// A slow simulator can take longer than iOS allows to start the process that
/// draws Live Activities after such a restart, so the test looks for the Live
/// Activity more than once.
final class AlarmCheck: XCTestCase {
  override func setUp() {
    continueAfterFailure = true
  }

  private var springboard: XCUIApplication {
    XCUIApplication(bundleIdentifier: "com.apple.springboard")
  }

  func testAthanAlarm() {
    // Late enough for a slow simulator to start the app, ask its two
    // questions and get the prayers ready.
    let first = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 + 150).rounded())
    let second = first.addingTimeInterval(300)
    let app = XCUIApplication()
    app.launchEnvironment["ATHAN_ALARM_CHECK_AT"] = "\(milliseconds(first)),\(milliseconds(second))"
    app.launch()
    note("test alarms at \(clock(first)) and \(clock(second))")

    // The app asks for notifications, then for alarms.
    var answered = 0
    for _ in 0..<3 {
      let left = first.timeIntervalSinceNow - 25
      if left < 5 { break }
      let allow = springboard.alerts.buttons
        .matching(NSPredicate(format: "label IN %@", ["Allow", "OK", "Continue"]))
        .firstMatch
      guard allow.waitForExistence(timeout: min(left, answered == 0 ? 90 : 25)) else { break }
      note("question \(answered + 1): \(springboard.alerts.firstMatch.label)")
      keep("question-\(answered + 1)")
      allow.tap()
      answered += 1
      pause(2)
    }
    note("questions answered: \(answered)")
    XCTAssertGreaterThanOrEqual(answered, 2, "The app should ask for notifications, then for alarms.")

    // First alarm: the phone is in use, with the app on screen.
    wait(until: first.addingTimeInterval(85))
    note("app on screen after the first alarm: \(app.state == .runningForeground)")
    keep("in-use-ringing")

    // Touch and hold the Dynamic Island: the Live Activity opens with the
    // buttons the app's extension draws.
    for attempt in 1...4 {
      openIsland()
      let offered = offers("Snooze")
      note("Live Activity opened, try \(attempt): Snooze offered: \(offered)")
      if offered { break }
      closeIsland()
      pause(12)
    }
    describe("in use, ringing, Live Activity open")
    keep("in-use-ringing-open")
    let snoozed = press("Snooze")
    XCTAssertTrue(snoozed, "The Live Activity should offer Snooze while the athan rings.")
    pause(6)
    keep("in-use-snoozed")
    openIsland()
    describe("in use, snoozed, Live Activity open")
    keep("in-use-snoozed-open")
    closeIsland()

    // The lock screen carries the same Live Activity: the snoozed athan.
    var stoppedSnoozed = false
    if lock() {
      pause(2)
      _ = lock()  // The second press lights the lock screen.
      pause(3)
      describe("lock screen, snoozed")
      keep("lock-screen-snoozed")
      stoppedSnoozed = press("Stop")
      note("stopped the snoozed athan from the lock screen: \(stoppedSnoozed)")
      pause(4)
      keep("lock-screen-after-stop")
      XCUIDevice.shared.press(.home)
      pause(2)
      XCUIDevice.shared.press(.home)
      pause(3)
    } else {
      note("this simulator cannot be locked from a test")
    }
    if !stoppedSnoozed {
      openIsland()
      stoppedSnoozed = press("Stop")
      note("stopped the snoozed athan from the Dynamic Island: \(stoppedSnoozed)")
      closeIsland()
    }
    keep("first-alarm-over")

    // Second alarm: the phone is locked and dark when it rings.
    note("seconds before the second alarm: \(Int(second.timeIntervalSinceNow))")
    let locked = lock()
    note("locked for the second alarm: \(locked)")
    wait(until: second.addingTimeInterval(85))
    describe("locked, ringing")
    keep("locked-ringing")
    var stopped = press("Stop")
    if !stopped {
      XCUIDevice.shared.press(.home)  // Lights the screen.
      pause(3)
      describe("locked, ringing, screen lit")
      keep("locked-ringing-lit")
      stopped = press("Stop")
    }
    for attempt in 1...3 where !stopped {
      openIsland()
      describe("ringing, Live Activity opened, try \(attempt)")
      keep("locked-ringing-open-\(attempt)")
      stopped = press("Stop")
      closeIsland()
      if !stopped { pause(12) }
    }
    note("stopped the second athan: \(stopped)")
    XCTAssertTrue(stopped, "A ringing athan should offer Stop.")
    pause(4)
    keep("second-alarm-over")

    // Back to the app, which logs what the iPhone reports at the end.
    XCUIDevice.shared.press(.home)
    pause(2)
    XCUIDevice.shared.press(.home)
    pause(2)
    app.activate()
    pause(8)
    keep("end")
  }

  /// Waits with the main thread free. A plain sleep through a SpringBoard
  /// restart gets the test runner closed by the watchdog.
  private func pause(_ seconds: TimeInterval) {
    _ = XCTWaiter().wait(for: [XCTestExpectation(description: "time")], timeout: seconds)
  }

  private func wait(until date: Date) {
    while date.timeIntervalSinceNow > 0 {
      pause(min(date.timeIntervalSinceNow, 5))
    }
  }

  private func lock() -> Bool {
    let button = NSSelectorFromString("pressLockButton")
    guard XCUIDevice.shared.responds(to: button) else { return false }
    XCUIDevice.shared.perform(button)
    return true
  }

  /// The Live Activity takes a few seconds to draw on a busy simulator.
  private func openIsland() {
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035))
      .press(forDuration: 1.3)
    pause(5)
  }

  private func closeIsland() {
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
    pause(1)
  }

  /// The buttons called [label], wherever on screen they are. Only buttons
  /// with exactly that name: the Live Activity as a whole also carries the
  /// names of its buttons, and a tap on it lands between them.
  private func buttons(_ label: String) -> XCUIElementQuery {
    springboard.buttons.matching(NSPredicate(format: "label ==[c] %@", label))
  }

  private func offers(_ label: String) -> Bool {
    buttons(label).count > 0
  }

  private func press(_ label: String) -> Bool {
    let found = buttons(label)
    let count = found.count
    for index in 0..<min(count, 6) {
      let button = found.element(boundBy: index)
      if button.exists && button.isHittable {
        note("press \(label): button at \(button.frame)")
        button.tap()
        return true
      }
    }
    note("no \(label) button to press (\(count) found)")
    return false
  }

  /// The lines of the screen's description that are about the alarm.
  private func describe(_ name: String) {
    let words = ["snooze", "stop", "athan", "alarm", "ringing", "resume"]
    let lines = springboard.debugDescription.split(separator: "\n")
    let about = lines.filter { line in
      let lower = line.lowercased()
      return words.contains { lower.contains($0) }
    }
    note("\(name): \(lines.count) lines on screen, \(about.count) about the alarm")
    for line in about.prefix(30) {
      note("  " + line.trimmingCharacters(in: .whitespaces))
    }
  }

  private func note(_ text: String) {
    print("ALARM_CHECK_UI \(text)")
  }

  private func keep(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func milliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
  }

  private func clock(_ date: Date) -> String {
    let format = DateFormatter()
    format.dateFormat = "HH:mm:ss"
    return format.string(from: date)
  }
}
