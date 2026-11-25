// The athan alarm in the Dynamic Island and on the Lock Screen.
//
// iOS draws the first full-screen alert itself. Once the phone is unlocked
// that alert is gone while the athan keeps ringing, and this Live Activity is
// what stays on screen, so it carries Stop and Snooze. While an athan is
// snoozed it shows the time left and a Stop that takes the snooze off.

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct AthanAlarmBundle: WidgetBundle {
  var body: some Widget {
    AthanAlarmLiveActivity()
  }
}

struct AthanAlarmLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AlarmAttributes<AthanAlarmData>.self) { context in
      AthanAlarmBanner(attributes: context.attributes, state: context.state)
        .padding(16)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "bell.fill")
            .foregroundStyle(context.attributes.tintColor)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          AthanAlarmTitle(attributes: context.attributes, state: context.state)
        }
        DynamicIslandExpandedRegion(.bottom) {
          AthanAlarmButtons(state: context.state)
        }
      } compactLeading: {
        Image(systemName: "bell.fill")
          .foregroundStyle(context.attributes.tintColor)
      } compactTrailing: {
        AthanAlarmGlance(state: context.state, tint: context.attributes.tintColor)
      } minimal: {
        Image(systemName: "bell.fill")
          .foregroundStyle(context.attributes.tintColor)
      }
      .keylineTint(context.attributes.tintColor)
    }
  }
}

/// The Lock Screen row: what is ringing, then the buttons.
struct AthanAlarmBanner: View {
  let attributes: AlarmAttributes<AthanAlarmData>
  let state: AlarmPresentationState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "bell.fill")
          .foregroundStyle(attributes.tintColor)
        AthanAlarmTitle(attributes: attributes, state: state)
        Spacer(minLength: 0)
      }
      AthanAlarmButtons(state: state)
    }
  }
}

struct AthanAlarmTitle: View {
  let attributes: AlarmAttributes<AthanAlarmData>
  let state: AlarmPresentationState

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(attributes.presentation.alert.title)
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      switch state.mode {
      case .countdown(let countdown):
        HStack(spacing: 4) {
          Text("Snoozed")
          Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
            .monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
      default:
        Text("Ringing")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }
}

/// The small side of the Dynamic Island: the time left while snoozed.
struct AthanAlarmGlance: View {
  let state: AlarmPresentationState
  let tint: Color

  var body: some View {
    switch state.mode {
    case .countdown(let countdown):
      Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: 48)
        .foregroundStyle(tint)
    default:
      Image(systemName: "speaker.wave.2.fill")
        .foregroundStyle(tint)
    }
  }
}

struct AthanAlarmButtons: View {
  let state: AlarmPresentationState

  var body: some View {
    HStack(spacing: 10) {
      switch state.mode {
      case .countdown, .paused:
        EmptyView()
      default:
        Button(intent: AthanSnoozeIntent(alarmID: state.alarmID.uuidString)) {
          Label("Snooze", systemImage: "zzz")
            .frame(maxWidth: .infinity)
        }
        .tint(.orange)
      }
      Button(intent: AthanStopIntent(alarmID: state.alarmID.uuidString)) {
        Label("Stop", systemImage: "stop.fill")
          .frame(maxWidth: .infinity)
      }
      .tint(.red)
    }
    .buttonStyle(.borderedProminent)
    .font(.headline)
    .lineLimit(1)
  }
}
