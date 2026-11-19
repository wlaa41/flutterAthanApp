import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/alert_preferences.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/sound_library.dart';
import '../widgets/alert_settings_controls.dart';
import '../widgets/sound_picker_sheet.dart';

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
  int _timedQuietStart = 540;
  int _timedQuietEnd = 1020;
  bool _busy = false;
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
                                  'Choose when to beep and when to hear the full Athan. Changes save automatically.',
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
                              if (_needsSetup) _setupBanner(_health!),
                            ],
                            if (_selectedSection ==
                                SettingsSection.reminders) ...[
                              _quietSection(prefs),
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
          (_android && !_health!.exactAlarmsEnabled));

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
            'On iPhone, recitations use short opening excerpts; Classic Athan uses a chime. Imported audio needs a PCM WAV under 30 seconds for alerts; other files use a beep. Previews play the full recording.',
          ),
        ),
    ],
  );

  Widget _quietSection(AlertPreferences prefs) => _section(
    title: 'Beep on chosen days',
    icon: Icons.work_outline,
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Use a quieter reminder'),
        subtitle: Text(
          prefs.quietEnabled
              ? 'Applies to Athan and Iqama. Other times keep your usual sounds.'
              : 'Choose days for a soft beep instead of the full Athan.',
        ),
        value: prefs.quietEnabled,
        onChanged: _busy
            ? null
            : (value) => _save(prefs.copyWith(quietEnabled: value)),
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
            _save(
              prefs.copyWith(
                quietStartMinute: allDay ? 0 : _timedQuietStart,
                quietEndMinute: allDay ? 0 : _timedQuietEnd,
              ),
            );
          },
          onWeekdaysChanged: (value) =>
              _save(prefs.copyWith(quietWeekdays: value)),
          onStartChanged: (value) =>
              _save(prefs.copyWith(quietStartMinute: value)),
          onEndChanged: (value) => _save(prefs.copyWith(quietEndMinute: value)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sound on these days'),
          subtitle: Text(_quietLabel(prefs.quietSoundId)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _chooseQuietSound,
        ),
        if (prefs.quietSoundId != 'silent' && prefs.quietSoundId != 'vibrate')
          _previewButtons(prefs.quietSoundId),
        Text(
          'Uses the time in ${PrayerService.instance.cityName}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );

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

  Widget _previewButtons(String soundId) => !_sound(soundId).canPreview
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Preview'),
              onPressed: _busy
                  ? null
                  : () => _run(
                      () async {
                        if (!_listeningAudioErrors) {
                          AudioService.instance.lastError.addListener(
                            _audioErrorChanged,
                          );
                          _listeningAudioErrors = true;
                        }
                        _previewStarted = true;
                        await AudioService.instance.playSound(_sound(soundId));
                      },
                      failure:
                          'This audio could not play. Try another sound or add the file again.',
                    ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop audio'),
              onPressed: _stopAudio,
            ),
          ],
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
                  : 'Allow precise timing for full recordings. Without it, phone tones may arrive late.',
              health.exactAlarmsEnabled,
              () => _run(() async {
                await NotificationService.instance
                    .requestExactAlarmPermission();
                await NotificationService.instance.refreshSchedule();
                await _loadHealth();
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('Battery settings'),
              subtitle: Text(
                health.batteryOptimized
                    ? 'Optimized. If reminders arrive late, allow background activity for Athan.'
                    : 'Background activity allowed',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: _busy
                  ? null
                  : () =>
                        _run(NotificationService.instance.openBatterySettings),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              health.scheduledCount == 0
                  ? 'No reminders are scheduled yet. Enable notifications and turn on the prayers you want.'
                  : health.scheduledUntil == null
                  ? '${health.scheduledCount} reminders scheduled.'
                  : '${health.scheduledCount} reminders scheduled through ${MaterialLocalizations.of(context).formatMediumDate(health.scheduledUntil!)}. Open the app regularly to keep them ready.',
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Test reminder'),
                onPressed: _busy
                    ? null
                    : () => _run(
                        NotificationService.instance.testNotification,
                        success:
                            'Test sent. Check your phone’s notification panel.',
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

  Future<void> _showAudioCredits() async {
    try {
      final credits = await rootBundle.loadString('asset/AUDIO_CREDITS.txt');
      if (!mounted) return;
      await _sheet<void>('Audio credits', [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(credits),
        ),
      ]);
    } catch (_) {
      if (mounted) _message('Audio credits could not be opened. Try again.');
    }
  }

  Future<void> _chooseQuietSound() async {
    const labels = {
      'beep': 'Soft beep',
      'double_beep': 'Double beep',
      'chime': 'Gentle chime',
      'vibrate': 'Vibration only',
      'silent': 'Silent notification',
    };
    final selected = await _sheet<String>('During quiet hours', [
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

  Widget _setupBanner(NotificationHealth health) {
    final needsNotifications = !health.notificationsEnabled;
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
                  : 'Allow precise alarms for full Athan recordings at the right time.',
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
