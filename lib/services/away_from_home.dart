import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where the phone was last found, as the phone sees it.
enum AwayPlace { home, away, unknown }

/// A point on the map with how far it may be off, in metres.
class HomePoint {
  const HomePoint(this.lat, this.lng, {this.accuracy});
  final double lat, lng;
  final double? accuracy;

  @override
  bool operator ==(Object other) =>
      other is HomePoint && other.lat == lat && other.lng == lng;
  @override
  int get hashCode => Object.hash(lat, lng);
}

/// "Beep away from home" as the phone reports it.
class AwayStatus {
  const AwayStatus({
    this.enabled = false,
    this.home,
    this.radius = AwayFromHome.defaultRadius,
    this.place = AwayPlace.unknown,
    this.location = false,
    this.background = false,
    this.locationOn = true,
    this.playServices = true,
    this.error,
  });

  final bool enabled;
  final HomePoint? home;

  /// Metres from home where "away" starts.
  final int radius;
  final AwayPlace place;

  /// Location permission while the app is open.
  final bool location;

  /// "Allow all the time": needed to notice leaving home with the app closed.
  final bool background;
  final bool locationOn;
  final bool playServices;
  final String? error;

  /// Away right now, so Athan and Iqama beep.
  bool get beepingNow => enabled && place == AwayPlace.away;

  /// What stops the rule from working, worst first. Empty when it works.
  List<String> get problems => [
    if (!location) 'Location permission is off.',
    if (location && !background)
      'Location must be set to "Allow all the time" to notice when you leave.',
    if (!locationOn) 'Location is turned off on the phone.',
    if (!playServices)
      'Google Play services is missing, so leaving home is only noticed at prayer time.',
  ];

  static AwayStatus fromNative(Map<String, dynamic> map) {
    final lat = map['lat'], lng = map['lng'];
    return AwayStatus(
      enabled: map['enabled'] == true,
      home: lat is num && lng is num
          ? HomePoint(lat.toDouble(), lng.toDouble())
          : null,
      radius: (map['radius'] as num?)?.toInt() ?? AwayFromHome.defaultRadius,
      place: switch (map['place']) {
        'home' => AwayPlace.home,
        'away' => AwayPlace.away,
        _ => AwayPlace.unknown,
      },
      location: map['location'] == true,
      background: map['background'] == true,
      locationOn: map['locationOn'] != false,
      playServices: map['playServices'] != false,
      error: map['error'] as String?,
    );
  }
}

/// Talks to the phone side (`AwayFromHome.kt`), which decides at the moment
/// each reminder fires. Android only.
class AwayFromHome {
  AwayFromHome._();
  static final AwayFromHome instance = AwayFromHome._();
  static const _channel = MethodChannel('athan/alarms');

  static const defaultRadius = 300;

  /// The distances offered, in metres. Under about 150 m phone location is
  /// too rough to tell home from next door.
  static const radii = [150, 300, 500, 1000];

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final ValueNotifier<AwayStatus?> status = ValueNotifier(null);

  Future<AwayStatus> load() async {
    if (!supported) return status.value = const AwayStatus();
    final map = await _channel.invokeMapMethod<String, dynamic>('awayStatus');
    return status.value = AwayStatus.fromNative(map ?? const {});
  }

  /// Saves the rule. The phone arms or removes its geofence.
  Future<AwayStatus> save({
    required bool enabled,
    required HomePoint? home,
    required int radius,
  }) async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'awaySave',
      jsonEncode({
        'enabled': enabled,
        'lat': home?.lat,
        'lng': home?.lng,
        'radius': radius,
      }),
    );
    return status.value = AwayStatus.fromNative(map ?? const {});
  }

  /// Location while the app is open. True when granted.
  Future<bool> requestLocation() async =>
      await _channel.invokeMethod<bool>('awayRequestLocation') ?? false;

  /// "Allow all the time". On Android 11+ this opens the app's location page.
  Future<bool> requestBackground() async =>
      await _channel.invokeMethod<bool>('awayRequestBackground') ?? false;

  Future<void> openLocationSettings() =>
      _channel.invokeMethod<void>('locationSettings');

  /// Where the phone is now, for "Set home to here". Null when no fix came.
  Future<HomePoint?> locate() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('awayLocate');
    final lat = map?['lat'], lng = map?['lng'];
    if (lat is! num || lng is! num) return null;
    return HomePoint(
      lat.toDouble(),
      lng.toDouble(),
      accuracy: (map?['accuracy'] as num?)?.toDouble(),
    );
  }
}
