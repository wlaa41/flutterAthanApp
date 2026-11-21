import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/away_from_home.dart';

/// The "Beep away from home" row on the Beep card and in Settings. It says
/// what the rule is doing now; a tap opens the setup sheet.
class AwayFromHomeSection extends StatefulWidget {
  const AwayFromHomeSection({super.key, this.divider = true, this.onChanged});

  /// A line above the row, as on the home Beep card.
  final bool divider;
  final VoidCallback? onChanged;

  @override
  State<AwayFromHomeSection> createState() => _AwayFromHomeSectionState();
}

class _AwayFromHomeSectionState extends State<AwayFromHomeSection>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF0F3931);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AwayFromHome.instance.status.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AwayFromHome.instance.status.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the phone's location page, or from somewhere else entirely.
    if (state == AppLifecycleState.resumed) _load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      await AwayFromHome.instance.load();
    } on PlatformException {
      // The row keeps its last state.
    } on MissingPluginException {
      // Tests and platforms without the phone side.
    }
  }

  Future<void> _open() async {
    final status = AwayFromHome.instance.status.value ?? const AwayStatus();
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AwayFromHomeSheet(status: status),
    );
    if (changed == true) widget.onChanged?.call();
    await _load();
  }

  static String describe(AwayStatus status) {
    if (!status.enabled) return 'Athan at home. Away from home, one beep.';
    if (status.problems.isNotEmpty) return status.problems.first;
    return switch (status.place) {
      AwayPlace.away => 'You are away from home, so Athan and Iqama beep.',
      AwayPlace.home => 'At home, so the Athan plays. Beeps once you leave.',
      AwayPlace.unknown =>
        'Not sure where you are yet, so the Athan plays as usual.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!AwayFromHome.instance.supported) return const SizedBox.shrink();
    final status = AwayFromHome.instance.status.value;
    if (status == null) return const SizedBox.shrink();
    final warn = status.enabled && status.problems.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.divider)
          Divider(height: 24, color: _green.withValues(alpha: .18)),
        Semantics(
          button: true,
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(
                    warn
                        ? Icons.location_off_outlined
                        : status.beepingNow
                        ? Icons.directions_walk
                        : Icons.home_outlined,
                    color: warn ? const Color(0xFFB3261E) : _green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Beep away from home',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          describe(status),
                          style: TextStyle(
                            color: warn
                                ? const Color(0xFFB3261E)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status.enabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'On',
                        style: TextStyle(
                          color: _green.withValues(alpha: .8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Icon(Icons.chevron_right, color: _green),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Setting up "Beep away from home". Nothing changes until Confirm.
class AwayFromHomeSheet extends StatefulWidget {
  const AwayFromHomeSheet({super.key, required this.status});
  final AwayStatus status;

  @override
  State<AwayFromHomeSheet> createState() => _AwayFromHomeSheetState();
}

class _AwayFromHomeSheetState extends State<AwayFromHomeSheet> {
  late bool _enabled = widget.status.enabled || widget.status.home == null;
  late HomePoint? _home = widget.status.home;
  late int _radius = widget.status.radius;
  bool _busy = false;
  String? _note;

  bool get _changed =>
      _enabled != widget.status.enabled ||
      _home != widget.status.home ||
      (_home != null && _radius != widget.status.radius);
  bool get _canConfirm => _changed && (!_enabled || _home != null) && !_busy;

  static String _distance(int metres) =>
      metres >= 1000 ? '${metres ~/ 1000} km' : '$metres m';

  Future<void> _setHomeHere() async {
    setState(() {
      _busy = true;
      _note = 'Finding where you are…';
    });
    try {
      if (!await AwayFromHome.instance.requestLocation()) {
        setState(() => _note = 'Location permission is needed to set home.');
        return;
      }
      final here = await AwayFromHome.instance.locate();
      setState(() {
        if (here == null) {
          _note =
              'Could not find where you are. Turn on Wi-Fi or step near a window, then try again.';
        } else {
          _home = here;
          final accuracy = here.accuracy;
          _note = accuracy == null
              ? 'Home is where you are now.'
              : 'Home is where you are now, to within ${accuracy.round()} m.';
        }
      });
    } on PlatformException {
      setState(() => _note = 'Could not find where you are. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final status = await AwayFromHome.instance.save(
        enabled: _enabled,
        home: _home,
        radius: _radius,
      );
      if (_enabled && status.location && !status.background && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Allow all the time'),
            content: const Text(
              'To notice that you left home while Athan is closed, Android needs location set to "Allow all the time". On the next screen, choose Allow all the time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (go == true) {
          await AwayFromHome.instance.requestBackground();
          await AwayFromHome.instance.load();
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on PlatformException {
      if (mounted) {
        setState(() => _note = 'That did not save. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = widget.status;
    final newHome = _home != null && _home != saved.home;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
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
                        'Beep away from home',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Away from home, every Athan and Iqama is your beep. At home they play as usual.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Beep away from home'),
                      value: _enabled,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Home'),
                      subtitle: Text(
                        _home == null
                            ? 'Not set. Set it while you are at home.'
                            : newHome
                            ? 'New home: where you are now.'
                            : 'Set.',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _setHomeHere,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        _home == null
                            ? 'Set home to where I am now'
                            : 'Move home to where I am now',
                      ),
                    ),
                    if (_note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Semantics(liveRegion: true, child: Text(_note!)),
                      ),
                    const SizedBox(height: 16),
                    Text('Away starts at', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final metres in AwayFromHome.radii)
                          ChoiceChip(
                            label: Text(_distance(metres)),
                            selected: _radius == metres,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() => _radius = metres),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From home, as the crow flies.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_enabled && saved.enabled && saved.problems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final problem in saved.problems)
                              Text(
                                problem,
                                style: const TextStyle(
                                  color: Color(0xFFB3261E),
                                ),
                              ),
                            if (!saved.background && saved.location)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        await AwayFromHome.instance
                                            .requestBackground();
                                        await AwayFromHome.instance.load();
                                      },
                                child: const Text('Allow all the time'),
                              ),
                            if (!saved.locationOn)
                              TextButton(
                                onPressed:
                                    AwayFromHome.instance.openLocationSettings,
                                child: const Text('Turn on location'),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Battery: Athan does not track you. It uses Android\'s low-power home boundary, and checks once at each prayer only if the phone has no recent location. Your location stays on this phone.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canConfirm ? _confirm : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
