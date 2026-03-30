import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kripto_app/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoPlatformApp());
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });
}
