import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rockxy_flutter_sample_guidance/main.dart';

void main() {
  Future<void> pumpSampleApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RockxyFlutterSampleApp());
  }

  testWidgets('sample app exposes Rockxy setup controls', (tester) async {
    await pumpSampleApp(tester);

    expect(find.text('Rockxy Flutter Sample'), findsOneWidget);
    expect(find.text('Current proxy target'), findsOneWidget);
    expect(find.text('Runtime'), findsOneWidget);
    expect(find.text('Send Request'), findsOneWidget);

    expect(find.text('Dart HttpClient'), findsOneWidget);
  });

  testWidgets('runtime selection updates the displayed proxy host',
      (tester) async {
    await pumpSampleApp(tester);

    expect(find.text('127.0.0.1:9090'), findsOneWidget);

    await tester.tap(find.textContaining('Android Emulator'));
    await tester.pumpAndSettle();

    expect(find.text('10.0.2.2:9090'), findsOneWidget);
  });
}
