import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/alert_preferences.dart';
import '../services/athan_catalog.dart';
import '../services/athan_downloads.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/sound_library.dart';
import '../widgets/alert_settings_controls.dart';
import '../widgets/away_from_home_tile.dart';
import '../widgets/beep_mode_card.dart';
import '../widgets/sound_picker_sheet.dart';
import '../widgets/weekly_beep.dart';

enum SettingsSection { essentials, reminders, phone }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialSection = SettingsSection.essentials,
  });

  final SettingsSection initialSection;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  AlertPreferences? _preferences;
  NotificationHealth? _health;
  List<SoundOption> _sounds = [];
  late SettingsSection _selectedSection;
  final _scrollController = ScrollController();

  /// Weekly beep edits not confirmed yet; null when there are none.
  AlertPreferences? _weeklyDraft;
  int _timedQuietStart = 540;
  int _timedQuietEnd = 1020;
  bool _busy = false;
  double? _powerDraft;
  bool _previewStarted = false;
  bool _listeningAudioErrors = false;
  String? _error;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    if (_listeningAudioErrors) {
      AudioService.instance.lastError.removeListener(_audioErrorChanged);
    }
    if (_previewStarted) _stopAudio(showError: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAfterResume();
    if (state == AppLifecycleState.paused) _stopAudio(showError: false);
  }

  Future<void> _refreshAfterResume() async {
    try {
      await NotificationService.instance.refreshSchedule();
      await _loadHealth();
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Reminders could not be updated. Check permissions, then tap Refresh reminders.',
        );
    }
  }

  Future<void> _load() async {
    try {
      final preferences = await AlertPreferences.load();
      final sounds = await SoundLibrary.instance.loadSounds();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _sounds = sounds;
        _error = null;
        if (preferences.quietStartMinute != preferences.quietEndMinute) {
          _timedQuietStart = preferences.quietStartMinute;
          _timedQuietEnd = preferences.quietEndMinute;
        }
      });
      await _loadHealth();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Your settings could not be loaded. Try again.',
        );
    }
  }

  Future<void> _loadHealth() async {
    try {
      final health = await NotificationService.instance.getHealth();
      if (mounted) setState(() => _health = health);
    } catch (_) {
      // Keep saved preferences usable when system status is unavailable.
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    String failure = 'That change could not be applied. Please try again.',
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && success != null) _message(success);
    } catch (error) {
      final message = error is _SettingsFailure ? error.message : failure;
      if (mounted) {
        setState(() => _error = message);
        _message(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(AlertPreferences next) => _run(() async {
    await next.save();
    if (mounted) setState(() => _preferences = next);
    try {
      await NotificationService.instance.refreshSchedule();
    } catch (_) {
      throw const _SettingsFailure(
        'Settings saved. Reminders could not be updated; check permissions, then tap Refresh reminders.',
      );
    }
    await _loadHealth();
  }, failure: 'Your settings could not be saved. Please try again.');

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _audioErrorChanged() {
    final message = AudioService.instance.lastError.value;
    if (mounted && message != null) {
      setState(() => _error = message);
      _message(message);
    }
  }

  Future<void> _stopAudio({bool showError = true}) async {
    _previewStarted = false;
    try {
      await AudioService.instance.stop();
    } catch (_) {
      if (mounted && showError)
        _message('Audio could not be stopped. Try again.');
    }
  }

  SoundOption _sound(String id) {
    for (final sound in _sounds) {
      if (sound.id == id) return sound;
    }
    return SoundCatalog.byId('beep');
  }

  String _quietLabel(String id) => switch (id) {
    'vibrate' => 'Vibration only',
    'silent' => 'Silent notification',
    _ => _sound(id).name,
  };

  @override
  Widget build(BuildContext context) {
    final prefs = _preferences;
    return Scaffold(
      appBar: AppBar(title: const Text('Make Athan yours')),
      body: SafeArea(
        child: prefs == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _category(
                              SettingsSection.essentials,
                              'Basics',
                              Icons.tune,
                            ),
                            _category(
                              SettingsSection.reminders,
                              'Reminders',
                              Icons.notifications_outlined,
                            ),
                            _category(
                              SettingsSection.phone,
                              'Phone setup',
                              Icons.verified_outlined,
                            ),
                          ],
                        ),
                      ),
                      if (_busy)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Saving and updating reminders',
                        ),
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(switch (_selectedSection) {
                                SettingsSection.essentials =>
                                  'Your city and your Athan. Changes save automatically.',
                                SettingsSection.reminders =>
                                  'Choose when to beep, how loud, and when to hear the full Athan. Changes save automatically.',
                                SettingsSection.phone =>
                                  'Check permissions and send a test reminder.',
                              }),
                            ),
                            if (_error != null) ...[
                              _notice(_error!, Icons.error_outline),
                              const SizedBox(height: 12),
                            ],
                            if (_selectedSection ==
                                SettingsSection.essentials) ...[
                              _locationSection(prefs),
                              _athanSection(prefs),
                              if (_android) _alarmScreenSection(prefs),
                              if (_needsSetup) _setupBanner(_health!),
                            ],
                            if (_selectedSection ==
                                SettingsSection.reminders) ...[
                              const BeepModeCard(
                                margin: EdgeInsets.only(bottom: 16),
                                showWeekly: false,
                              ),
                              _beepSoundSection(prefs),
                              _quietSection(prefs),
                              if (_android)
                                _section(
                                  title: 'Away from home',
                                  icon: Icons.home_outlined,
                                  children: const [
                                    AwayFromHomeSection(divider: false),
                                  ],
                                ),
                              _iqamaSection(prefs),
                            ],
                            if (_selectedSection == SettingsSection.phone) ...[
                              if (_needsSetup) _setupBanner(_health!),
                              _permissionSection(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  bool get _needsSetup =>
      _health != null &&
      _health!.supported &&
      (!_health!.notificationsEnabled ||
          (_android &&
              (!_health!.exactAlarmsEnabled || _health!.batteryOptimized)));

  Widget _category(SettingsSection section, String label, IconData icon) =>
      ChoiceChip(
        avatar: Icon(icon, size: 18),
        showCheckmark: false,
        label: Text(label),
        selected: _selectedSection == section,
        onSelected: _busy
            ? null
            : (_) {
                if (_previewStarted) _stopAudio(showError: false);
                setState(() => _selectedSection = section);
                if (_scrollController.hasClients) _scrollController.jumpTo(0);
              },
      );

  Widget _locationSection(AlertPreferences prefs) => _section(
    title: 'Location & prayer times',
    icon: Icons.location_on_outlined,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('City'),
        subtitle: Text(PrayerService.instance.cityName),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _selectCity,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Calculation method'),
        subtitle: Text(
          PrayerService.calculationMethods[PrayerService
                  .instance
                  .calculationMethod] ??
              'Custom method',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _selectMethod,
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'No background location tracking. Saved times work offline; check your local mosque when choosing a calculation method.',
        ),
      ),
    ],
  );

  Widget _athanSection(AlertPreferences prefs) => _section(
    title: 'Athan sound',
    icon: Icons.volume_up_outlined,
    children: [
      _soundTile(
        'Choose or add a sound',
        prefs.athanSoundId,
        () => _chooseSound(false),
      ),
      TextButton.icon(
        onPressed: _showAudioCredits,
        icon: const Icon(Icons.info_outline, size: 18),
        label: const Text('Audio credits'),
      ),
      if (_ios)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'On iPhone, recitations use short opening excerpts; Classic Athan uses a chime. Imported audio needs a PCM WAV under 30 seconds for alerts; other files and added athans use a beep. Previews play the full recording.',
          ),
        ),
    ],
  );

  /// The black screen the athan opens on Android, like an alarm clock's.
  Widget _alarmScreenSection(AlertPreferences prefs) {
    final health = _health;
    final snoozed = health?.snoozedUntil;
    return _section(
      title: 'Alarm screen',
      icon: Icons.alarm_on_outlined,
      children: [
        const Text(
          'When the athan plays, the screen turns black with the time, like an alarm clock. Slide right to stop, slide left to snooze. The notification has Snooze and Stop too.',
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Easier screen'),
          subtitle: const Text(
            'Any tap on the alarm screen stops the athan. Slide left still snoozes.',
          ),
          value: prefs.easierScreen,
          onChanged: _busy
              ? null
              : (value) => _save(prefs.copyWith(easierScreen: value)),
        ),
        const SizedBox(height: 4),
        Text('Snooze for', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final minutes in AlertPreferences.snoozeChoices)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: prefs.snoozeMinutes == minutes,
                onSelected: _busy || prefs.snoozeMinutes == minutes
                    ? null
                    : (_) => _save(prefs.copyWith(snoozeMinutes: minutes)),
              ),
          ],
        ),
        if (health != null && !health.fullScreenAllowed) ...[
          const SizedBox(height: 8),
          _statusTile(
            'Full-screen alarm is off',
            'The athan still plays, but the black screen cannot open over the lock screen. Tap and allow full screen notifications for Athan.',
            false,
            () => _run(() async {
              await NotificationService.instance.openFullScreenSettings();
              await _loadHealth();
            }),
          ),
        ],
        if (snoozed != null && snoozed.isAfter(DateTime.now()))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.snooze),
            title: Text('Snoozed until ${_when(snoozed)}'),
            trailing: TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await NotificationService.instance.cancelSnooze();
                      await _loadHealth();
                    }, success: 'Snooze cancelled.'),
              child: const Text('Cancel snooze'),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Try the alarm screen'),
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await NotificationService.instance.testNotification();
                    final health = _health;
                    if (mounted && health != null && !health.canPlayAloud)
                      _message(
                        'The phone is on silent or Do Not Disturb, so the athan does not play and the alarm screen stays closed.',
                      );
                  }, failure: 'The test could not start. Try again.'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Plays your athan now and opens the screen. A beep, vibration or silent reminder stays a notification.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _editWeekly(AlertPreferences saved, AlertPreferences next) =>
      setState(() => _weeklyDraft = next.sameWeekly(saved) ? null : next);

  Widget _quietSection(AlertPreferences saved) {
    // The controls show the draft; Confirm saves it, Cancel drops it.
    final prefs = _weeklyDraft ?? saved;
    final unsaved = _weeklyDraft != null;
    return _section(
      title: 'Weekly beep days',
      icon: Icons.work_outline,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Beep on these days'),
          subtitle: Text(
            prefs.quietEnabled
                ? 'Athan and Iqama are your beep on these days and hours. Other times keep your usual sounds.'
                : 'One beep on the same days every week, such as work days.',
          ),
          value: prefs.quietEnabled,
          onChanged: _busy
              ? null
              : (value) =>
                    _editWeekly(saved, prefs.copyWith(quietEnabled: value)),
        ),
        if (prefs.quietEnabled) ...[
          const Divider(height: 24),
          QuietScheduleEditor(
            weekdays: prefs.quietWeekdays,
            startMinute: prefs.quietStartMinute,
            endMinute: prefs.quietEndMinute,
            enabled: !_busy,
            onAllDayChanged: (allDay) {
              if (allDay == (prefs.quietStartMinute == prefs.quietEndMinute))
                return;
              if (allDay && prefs.quietStartMinute != prefs.quietEndMinute) {
                _timedQuietStart = prefs.quietStartMinute;
                _timedQuietEnd = prefs.quietEndMinute;
              }
              _editWeekly(
                saved,
                prefs.copyWith(
                  quietStartMinute: allDay ? 0 : _timedQuietStart,
                  quietEndMinute: allDay ? 0 : _timedQuietEnd,
                ),
              );
            },
            onWeekdaysChanged: (value) =>
                _editWeekly(saved, prefs.copyWith(quietWeekdays: value)),
            onStartChanged: (value) =>
                _editWeekly(saved, prefs.copyWith(quietStartMinute: value)),
            onEndChanged: (value) =>
                _editWeekly(saved, prefs.copyWith(quietEndMinute: value)),
          ),
          const SizedBox(height: 8),
          Text(
            'Plays your beep sound (${_quietLabel(prefs.quietSoundId)}). Uses the time in ${PrayerService.instance.cityName}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (unsaved)
          WeeklyConfirmBar(
            draft: prefs,
            busy: _busy,
            onCancel: () => setState(() => _weeklyDraft = null),
            onConfirm: () async {
              final draft = _weeklyDraft;
              if (draft == null) return;
              await _save(_preferences!.withWeeklyFrom(draft));
              // A failed save leaves the draft open to try again.
              if (mounted && _preferences!.sameWeekly(draft))
                setState(() => _weeklyDraft = null);
            },
          ),
      ],
    );
  }

  static const _powerNames = ['Soft', 'Medium', 'Strong', 'Loud', 'Maximum'];

  /// The beep itself: which tone, how loud, and how it reaches you. Shared by
  /// Beep mode and by the chosen-days schedule.
  Widget _beepSoundSection(AlertPreferences prefs) {
    final sound = _sound(prefs.quietSoundId);
    final power = (_powerDraft ?? prefs.beepPower.toDouble()).round();
    return _section(
      title: 'Beep sound and power',
      icon: Icons.graphic_eq,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound'),
          subtitle: Text(_quietLabel(prefs.quietSoundId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _chooseQuietSound,
        ),
        if (sound.hasPowerLevels) ...[
          const SizedBox(height: 4),
          Text('Power: ${_powerNames[power - 1]}'),
          Slider(
            value: power.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: _powerNames[power - 1],
            semanticFormatterCallback: (value) =>
                _powerNames[value.round() - 1],
            onChanged: _busy
                ? null
                : (value) => setState(() => _powerDraft = value),
            onChangeEnd: (value) async {
              final next = prefs.copyWith(beepPower: value.round());
              await _save(next);
              if (mounted) setState(() => _powerDraft = null);
              await _testBeep(next);
            },
          ),
        ],
        if (!sound.isSilent)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Test beep'),
              onPressed: _busy ? null : () => _testBeep(prefs),
            ),
          ),
        if (_android) ...[
          const Divider(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibrate with the beep'),
            subtitle: const Text('A short buzz, so you feel it in a pocket.'),
            value: prefs.beepVibrate,
            onChanged: _busy
                ? null
                : (value) => _save(prefs.copyWith(beepVibrate: value)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use alarm volume'),
            subtitle: const Text(
              'The beep follows your phone’s alarm volume, which is usually set louder than notifications.',
            ),
            value: prefs.beepAlarmVolume,
            onChanged: _busy
                ? null
                : (value) => _save(prefs.copyWith(beepAlarmVolume: value)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('Add the quick settings tile'),
            subtitle: const Text(
              'Swipe down and tap “Athan beep” to switch without opening the app. Long-pressing the app icon offers “Beep today” too.',
            ),
            onTap: _busy ? null : _addBeepTile,
          ),
        ],
        if (_ios)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'On iPhone the beep plays at your notification volume; the power setting chooses a louder or softer tone.',
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Your phone’s silent mode and Do Not Disturb still apply.',
          ),
        ),
      ],
    );
  }

  Future<void> _testBeep(AlertPreferences prefs) async {
    try {
      if (await NotificationService.instance.previewBeep(prefs)) return;
      final sound = _sound(prefs.quietSoundId).atPower(prefs.beepPower);
      if (!sound.canPreview) {
        if (mounted) _message('${sound.name} makes no sound to test.');
        return;
      }
      if (!_listeningAudioErrors) {
        AudioService.instance.lastError.addListener(_audioErrorChanged);
        _listeningAudioErrors = true;
      }
      _previewStarted = true;
      await AudioService.instance.playSound(sound);
    } catch (_) {
      if (mounted) _message('The beep could not play. Try again.');
    }
  }

  Future<void> _addBeepTile() async {
    final offered = await NotificationService.instance.requestBeepTile();
    if (!mounted || offered) return;
    _message(
      'Swipe down twice, tap the pencil, then drag “Athan beep” into your tiles.',
    );
  }

  Widget _iqamaSection(AlertPreferences prefs) => _section(
    title: 'Iqama reminders',
    icon: Icons.notifications_active_outlined,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Remind me for Iqama'),
        subtitle: const Text('An extra reminder after each enabled prayer.'),
        value: prefs.iqamaEnabled,
        onChanged: _busy
            ? null
            : (value) => _save(prefs.copyWith(iqamaEnabled: value)),
      ),
      if (prefs.iqamaEnabled) ...[
        const Divider(height: 24),
        ReminderTimingEditor(
          delayMinutes: prefs.iqamaDelayMinutes,
          repeatCount: prefs.iqamaRepeatCount,
          intervalMinutes: prefs.iqamaRepeatIntervalMinutes,
          enabled: !_busy,
          onDelayChanged: (value) =>
              _save(prefs.copyWith(iqamaDelayMinutes: value)),
          onRepeatChanged: (value) =>
              _save(prefs.copyWith(iqamaRepeatCount: value)),
          onIntervalChanged: (value) =>
              _save(prefs.copyWith(iqamaRepeatIntervalMinutes: value)),
        ),
        const SizedBox(height: 8),
        _soundTile('Iqama sound', prefs.iqamaSoundId, () => _chooseSound(true)),
      ],
    ],
  );

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );

  Widget _notice(String message, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
  );

  Widget _soundTile(String title, String soundId, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(_sound(soundId).name),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : onTap,
      );

  Widget _permissionSection() {
    final health = _health;
    return _section(
      title: 'Reminder readiness',
      icon: Icons.verified_outlined,
      children: [
        if (health == null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Check this phone'),
            subtitle: const Text(
              'Review notification access and scheduled reminders.',
            ),
            trailing: const Icon(Icons.refresh),
            onTap: _busy ? null : _loadHealth,
          )
        else if (!health.supported)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Scheduled reminders are available on Android and iPhone.',
            ),
          )
        else ...[
          _statusTile(
            'Notifications',
            health.notificationsEnabled
                ? 'Allowed'
                : _android
                ? 'Off. The Athan still plays, but nothing shows on screen and silent-mode reminders are missed.'
                : 'Permission needed to show reminders',
            health.notificationsEnabled,
            () => _run(() async {
              if (health.notificationsEnabled) {
                await NotificationService.instance.openAppSettings();
              } else {
                await NotificationService.instance
                    .requestNotificationPermission();
                await NotificationService.instance.refreshSchedule();
              }
              await _loadHealth();
            }),
          ),
          if (_android) ...[
            _statusTile(
              'On-time alarms',
              health.exactAlarmsEnabled
                  ? 'Allowed'
                  : 'Off. Android will not let the Athan play without it. Tap to allow "Alarms & reminders".',
              health.exactAlarmsEnabled,
              () => _run(() async {
                await NotificationService.instance
                    .requestExactAlarmPermission();
                await NotificationService.instance.refreshSchedule();
                await _loadHealth();
              }),
            ),
            _statusTile(
              'Battery',
              health.batteryOptimized
                  ? 'Battery saving is on for Athan, so the phone may hold the Athan back. Tap and choose Allow.'
                  : 'Not restricted',
              !health.batteryOptimized,
              () => _run(() async {
                if (health.batteryOptimized) {
                  await NotificationService.instance.requestBatteryExemption();
                } else {
                  await NotificationService.instance.openBatterySettings();
                }
                await _loadHealth();
              }),
            ),
            _statusTile(
              'Alarm screen',
              health.fullScreenAllowed
                  ? 'Allowed. The athan opens the black alarm screen over the lock screen.'
                  : 'Off. The athan plays, but the alarm screen cannot open over the lock screen. Tap to allow full screen notifications.',
              health.fullScreenAllowed,
              () => _run(() async {
                await NotificationService.instance.openFullScreenSettings();
                await _loadHealth();
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                health.canPlayAloud
                    ? Icons.volume_up_outlined
                    : Icons.vibration,
              ),
              title: const Text('Sound mode'),
              subtitle: Text(_soundModeText(health)),
            ),
          ],
          if (health.nextTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Next: ${health.nextTitle ?? 'Prayer reminder'} at ${_when(health.nextTime!)}.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              health.scheduledCount == 0
                  ? 'No reminders are scheduled yet. Turn on the prayers you want.'
                  : health.scheduledUntil == null
                  ? '${health.scheduledCount} reminders scheduled.'
                  : '${health.scheduledCount} reminders scheduled through ${MaterialLocalizations.of(context).formatMediumDate(health.scheduledUntil!)}. Open the app regularly to keep them ready.',
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_android)
                FilledButton.icon(
                  icon: const Icon(Icons.alarm),
                  label: const Text('Test in 1 minute'),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final at = await NotificationService.instance
                              .testSoon();
                          await _loadHealth();
                          if (mounted)
                            _message(
                              'Test Athan at ${_when(at)}. Lock the phone now and wait.',
                            );
                        }, failure: 'The test could not be set. Try again.'),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow_outlined),
                label: Text(_android ? 'Play now' : 'Test reminder'),
                onPressed: _busy
                    ? null
                    : () => _run(
                        NotificationService.instance.testNotification,
                        success: _android
                            ? null
                            : 'Test sent. Check your phone’s notification panel.',
                        failure:
                            'The test could not be sent. Check notification permissions.',
                      ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(NotificationService.instance.openAppSettings),
                child: const Text('Phone settings'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await NotificationService.instance.refreshSchedule();
                        await _loadHealth();
                      }, success: 'Reminder schedule refreshed.'),
                child: const Text('Refresh reminders'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Athan schedules reminders with your phone. No constant background polling or GPS is needed.',
        ),
      ],
    );
  }

  String _when(DateTime time) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(time),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  String _soundModeText(NotificationHealth health) {
    if (health.doNotDisturb)
      return 'Do Not Disturb is on. Reminders follow its rules and the Athan does not play.';
    switch (health.ringer) {
      case RingerMode.silent:
      case RingerMode.vibrate:
        return 'Phone is on ${health.ringer.name}. It vibrates at prayer time instead of playing the Athan.';
      case RingerMode.normal:
        return health.playbackMuted
            ? 'The "Athan alarm" notification category is turned down in phone settings, so the Athan cannot play.'
            : 'Ring mode. The Athan plays at alarm volume.';
    }
  }

  Widget _statusTile(
    String title,
    String subtitle,
    bool ready,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(ready ? Icons.check_circle_outline : Icons.info_outline),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: _busy ? null : onTap,
  );

  Future<T?> _sheet<T>(String title, List<Widget> items) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    children: items,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _chooseSound(bool iqama) async {
    await _stopAudio();
    if (!mounted) return;
    final selected = await showModalBottomSheet<SoundOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SoundPickerSheet(
        sounds: _sounds,
        selectedId: iqama
            ? _preferences!.iqamaSoundId
            : _preferences!.athanSoundId,
        iqama: iqama,
        isIOS: _ios,
        playbackError: AudioService.instance.lastError,
        onPreview: (sound) async {
          _previewStarted = true;
          await AudioService.instance.playSound(sound);
        },
        onStop: () => AudioService.instance.stop(),
        isPlayingStream: AudioService.instance.playerStateStream.map(
          (state) =>
              state.playing &&
              state.processingState != ProcessingState.completed,
        ),
        onImport: () async {
          final sound = await SoundLibrary.instance.importSound();
          if (sound != null && mounted) {
            setState(() => _sounds = [..._sounds, sound]);
          }
          return sound;
        },
        moreAthans: athanCatalog,
        onAddAthan: (athan, onProgress) async {
          await AthanDownloads.instance.add(athan, onProgress: onProgress);
          return _reloadAddedAthans();
        },
        onRemoveAthan: (athan) async {
          await AthanDownloads.instance.remove(athan);
          await _reloadAddedAthans();
        },
      ),
    );
    await _stopAudio();
    if (selected == null || !mounted) return;
    await _save(
      iqama
          ? _preferences!.copyWith(iqamaSoundId: selected.id)
          : _preferences!.copyWith(athanSoundId: selected.id),
    );
  }

  /// Reads the sound list again after an athan was added or removed, and
  /// returns the added athans now on the phone.
  Future<List<SoundOption>> _reloadAddedAthans() async {
    final sounds = await SoundLibrary.instance.loadSounds();
    if (mounted) setState(() => _sounds = sounds);
    return [
      for (final sound in sounds)
        if (AthanDownloads.isAddedSound(sound.id)) sound,
    ];
  }

  Future<void> _showAudioCredits() async {
    try {
      final credits = await rootBundle.loadString('asset/AUDIO_CREDITS.txt');
      if (!mounted) return;
      final added = StringBuffer(
        'ATHANS YOU CAN ADD\n'
        'These recordings are not part of the app. Your phone fetches one '
        'from the source below when you add it, and checks it against the '
        'checksum recorded in tools/athan_downloads.json.\n',
      );
      // A bundled athan is part of the app; its credit is in the list above.
      for (final athan in athanCatalog.where((a) => a.bundled == null)) {
        added.write('\n${athan.name}: ${athan.source}');
      }
      await _sheet<void>('Audio credits', [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText('${credits.trimRight()}\n\n$added'),
        ),
      ]);
    } catch (_) {
      if (mounted) _message('Audio credits could not be opened. Try again.');
    }
  }

  Future<void> _chooseQuietSound() async {
    const labels = {
      'beep': 'Beep',
      'double_beep': 'Double beep',
      'chime': 'Gentle chime',
      'strong_beep': 'Strong beep',
      'vibrate': 'Vibration only',
      'silent': 'Silent notification',
    };
    final selected = await _sheet<String>('Beep sound', [
      for (final entry in labels.entries)
        ListTile(
          title: Text(entry.value),
          leading: Icon(
            entry.key == _preferences!.quietSoundId
                ? Icons.check_circle
                : Icons.circle_outlined,
          ),
          onTap: () => Navigator.pop(context, entry.key),
        ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Your phone’s silent mode and Do Not Disturb settings still apply.',
        ),
      ),
      if (_ios)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'iPhone controls vibration in its notification settings. The app cannot force a vibration for silent alerts.',
          ),
        ),
    ]);
    if (selected != null && mounted)
      await _save(_preferences!.copyWith(quietSoundId: selected));
  }

  Future<void> _selectCity() async {
    final selected = await _sheet<Map<String, dynamic>>('Choose city', [
      for (final city in PrayerService.presetCities)
        ListTile(
          title: Text(city['name'] as String),
          selected: PrayerService.instance.cityName == city['name'],
          trailing: PrayerService.instance.cityName == city['name']
              ? const Icon(Icons.check)
              : null,
          onTap: () => Navigator.pop(context, city),
        ),
    ]);
    if (selected == null || !mounted) return;
    await _run(() async {
      await PrayerService.instance.updateLocation(
        lat: selected['lat'] as double,
        lng: selected['lng'] as double,
        city: selected['name'] as String,
        method: selected['method'] as int?,
        timeZoneName: selected['timezone'] as String?,
      );
      if (mounted) setState(() {});
      await NotificationService.instance.refreshSchedule();
      await _loadHealth();
    });
  }

  Widget _batteryBanner() => Card(
    margin: const EdgeInsets.only(bottom: 16),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let the Athan run in the background',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Battery saving can stop the Athan from playing. Choose Allow on the next screen.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await NotificationService.instance
                        .requestBatteryExemption();
                    await _loadHealth();
                  }),
            child: const Text('Allow background'),
          ),
        ],
      ),
    ),
  );

  Widget _setupBanner(NotificationHealth health) {
    // Worst blocker first: no on-time alarms means no Athan at all.
    if (_android && health.exactAlarmsEnabled && health.notificationsEnabled)
      return _batteryBanner();
    final needsNotifications =
        !health.notificationsEnabled &&
        (!_android || health.exactAlarmsEnabled);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              needsNotifications
                  ? 'Enable prayer reminders'
                  : 'Enable on-time Athan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              needsNotifications
                  ? 'Allow notifications so your phone can remind you when it is time to pray.'
                  : 'Allow "Alarms & reminders" so the Athan can play at prayer time.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (needsNotifications) {
                        await NotificationService.instance
                            .requestNotificationPermission();
                      } else {
                        await NotificationService.instance
                            .requestExactAlarmPermission();
                      }
                      await NotificationService.instance.refreshSchedule();
                      await _loadHealth();
                    }),
              child: Text(
                needsNotifications
                    ? 'Allow notifications'
                    : 'Set up precise alarms',
              ),
            ),
            if (needsNotifications)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(NotificationService.instance.openAppSettings),
                child: const Text('Open phone settings'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMethod() async {
    final selected = await _sheet<int>('Calculation method', [
      for (final method in PrayerService.calculationMethods.entries)
        ListTile(
          title: Text(method.value),
          selected: PrayerService.instance.calculationMethod == method.key,
          trailing: PrayerService.instance.calculationMethod == method.key
              ? const Icon(Icons.check)
              : null,
          onTap: () => Navigator.pop(context, method.key),
        ),
    ]);
    if (selected == null || !mounted) return;
    await _run(() async {
      final service = PrayerService.instance;
      await service.updateLocation(
        lat: service.latitude,
        lng: service.longitude,
        city: service.cityName,
        method: selected,
        timeZoneName: service.timeZoneName,
      );
      if (mounted) setState(() {});
      await NotificationService.instance.refreshSchedule();
      await _loadHealth();
    });
  }
}

class _SettingsFailure implements Exception {
  const _SettingsFailure(this.message);
  final String message;
}
