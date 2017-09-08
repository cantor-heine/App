// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import '../rendering/mock_canvas.dart';

void main() {
  testWidgets('Placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const Placeholder());
    expect(tester.renderObject<RenderBox>(find.byType(Placeholder)).size, const Size(800.0, 600.0));
    await tester.pumpWidget(const Center(child: const Placeholder()));
    expect(tester.renderObject<RenderBox>(find.byType(Placeholder)).size, const Size(800.0, 600.0));
    await tester.pumpWidget(new Stack(textDirection: TextDirection.ltr, children: <Widget>[const Positioned(top: 0.0, bottom: 0.0, child: const Placeholder())]));
    expect(tester.renderObject<RenderBox>(find.byType(Placeholder)).size, const Size(400.0, 600.0));
    await tester.pumpWidget(new Stack(textDirection: TextDirection.ltr, children: <Widget>[const Positioned(left: 0.0, right: 0.0, child: const Placeholder())]));
    expect(tester.renderObject<RenderBox>(find.byType(Placeholder)).size, const Size(800.0, 400.0));
    await tester.pumpWidget(new Stack(textDirection: TextDirection.ltr, children: <Widget>[const Positioned(top: 0.0, child: const Placeholder(fallbackWidth: 200.0, fallbackHeight: 300.0))]));
    expect(tester.renderObject<RenderBox>(find.byType(Placeholder)).size, const Size(200.0, 300.0));
  });

  testWidgets('Placeholder color', (WidgetTester tester) async {
    await tester.pumpWidget(const Placeholder());
    expect(tester.renderObject(find.byType(Placeholder)), paints..path(color: const Color(0xFF455A64)));
    await tester.pumpWidget(const Placeholder(color: const Color(0xFF00FF00)));
    expect(tester.renderObject(find.byType(Placeholder)), paints..path(color: const Color(0xFF00FF00)));
  });

  testWidgets('Placeholder stroke width', (WidgetTester tester) async {
    await tester.pumpWidget(const Placeholder());
    expect(tester.renderObject(find.byType(Placeholder)), paints..path(strokeWidth: 2.0));
    await tester.pumpWidget(const Placeholder(strokeWidth: 10.0));
    expect(tester.renderObject(find.byType(Placeholder)), paints..path(strokeWidth: 10.0));
  });
}
