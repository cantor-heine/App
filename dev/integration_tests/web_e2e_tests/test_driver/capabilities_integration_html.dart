// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:web_e2e_tests/capabilities_main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capabilities integration test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();
    final Finder textFinder = find.byKey(const Key('isCanvaskit bool is false'));
    expect(textFinder, findsOneWidget);
    final Text text = tester.widget(textFinder);
    expect(text.data, 'The app is not canvasKit');
  });
}
