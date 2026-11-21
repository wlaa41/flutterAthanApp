import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pro/services/away_from_home.dart';
import 'package:flutter_pro/widgets/away_from_home_tile.dart';

void main() {
  const channel = MethodChannel('athan/alarms');
  late List<MethodCall> calls;
  late Map<String, dynamic> phone;

  setUp(() {
    calls = [];
    phone = {
      'enabled': false,
      'radius': 300,
      'place': 'unknown',
      'location': false,
      'background': false,
      'locationOn': true,
      'playServices': true,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'awayStatus':
              return phone;
            case 'awayRequestLocation':
              phone['location'] = true;
              return true;
            case 'awayLocate':
              return {'lat': 51.539, 'lng': 0.144, 'accuracy': 12.0};
            case 'awaySave':
              final args = jsonDecode(call.arguments as String) as Map;
              phone = {
                ...phone,
                'enabled': args['enabled'],
                'lat': args['lat'],
                'lng': args['lng'],
                'radius': args['radius'],
                'place': 'home',
              };
              return phone;
            case 'awayRequestBackground':
              phone['background'] = true;
              phone['place'] = 'away';
              return true;
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: AwayFromHomeSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  FilledButton confirm(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Confirm'));

  test('the phone report reads into what blocks the rule', () {
    final status = AwayStatus.fromNative({
      'enabled': true,
      'lat': 51.5,
      'lng': 0.1,
      'radius': 500,
      'place': 'away',
      'location': true,
      'background': false,
    });
    expect(status.home, const HomePoint(51.5, 0.1));
    expect(status.radius, 500);
    expect(status.beepingNow, isTrue);
    expect(status.problems.single, contains('Allow all the time'));
    expect(
      AwayStatus.fromNative({'enabled': false}).problems.first,
      'Location permission is off.',
    );
  });

  testWidgets('set home, pick a distance, Confirm, then allow all the time', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Beep away from home'), findsOneWidget);
    expect(
      find.text('Athan at home. Away from home, one beep.'),
      findsOneWidget,
    );

    await press(tester, find.text('Beep away from home'));
    // Nothing to confirm without a home.
    expect(confirm(tester).onPressed, isNull);
    await press(tester, find.text('Set home to where I am now'));
    expect(
      find.text('Home is where you are now, to within 12 m.'),
      findsOneWidget,
    );
    await press(tester, find.text('500 m'));
    expect(calls.where((c) => c.method == 'awaySave'), isEmpty);

    await press(tester, find.text('Confirm'));
    final saved =
        jsonDecode(calls.singleWhere((c) => c.method == 'awaySave').arguments)
            as Map;
    expect(saved, {
      'enabled': true,
      'lat': 51.539,
      'lng': 0.144,
      'radius': 500,
    });
    // Android needs "Allow all the time" to notice leaving with the app closed.
    expect(find.text('Allow all the time'), findsOneWidget);
    await press(tester, find.text('Continue'));
    expect(
      calls.where((c) => c.method == 'awayRequestBackground'),
      hasLength(1),
    );
    expect(find.text('Away starts at'), findsNothing);
    expect(
      find.text('You are away from home, so Athan and Iqama beep.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel saves nothing', (tester) async {
    phone = {
      ...phone,
      'enabled': true,
      'lat': 51.539,
      'lng': 0.144,
      'place': 'home',
      'location': true,
      'background': true,
    };
    await show(tester);
    expect(
      find.text('At home, so the Athan plays. Beeps once you leave.'),
      findsOneWidget,
    );
    await press(tester, find.text('Beep away from home'));
    expect(confirm(tester).onPressed, isNull);
    await press(tester, find.text('1 km'));
    expect(confirm(tester).onPressed, isNotNull);
    await press(tester, find.byType(Switch));
    await press(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
    expect(calls.where((c) => c.method == 'awaySave'), isEmpty);
    expect(
      find.text('At home, so the Athan plays. Beeps once you leave.'),
      findsOneWidget,
    );
  });

  testWidgets('a missing permission shows on the row', (tester) async {
    phone = {
      ...phone,
      'enabled': true,
      'lat': 51.539,
      'lng': 0.144,
      'location': true,
      'background': false,
    };
    await show(tester);
    expect(find.textContaining('Allow all the time'), findsOneWidget);
    expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
  });
}
