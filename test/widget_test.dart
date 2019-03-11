// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('App title, theme and correct buttons are displayed', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());

  MaterialApp app = find.byType(MaterialApp).evaluate().first.widget;
  expect(app.theme.brightness, equals(Brightness.light));
  expect(app.title, 'Flutters');

  expect((find.byIcon(Icons.send)), findsOneWidget);
  expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Write message', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.enterText(find.byType(TextField), 'Moni is awesome');
    expect(find.text('Moni is awesome'), findsOneWidget);
  });
}
