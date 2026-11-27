import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bio_secure_flutter/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BioSecureApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
