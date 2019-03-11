import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('App title, theme and correct buttons are displayed',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    MaterialApp app = find.byType(MaterialApp).evaluate().first.widget;
    expect(app.theme.brightness, equals(Brightness.light));
    expect(app.title, 'Flutters');

    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('Write message', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.enterText(find.byType(TextField), 'Moni is awesome');
    expect(find.text('Moni is awesome'), findsOneWidget);
  });
}
