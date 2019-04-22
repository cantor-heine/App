// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SnackBarThemeData copyWith, ==, hashCode basics', () {
    expect(const SnackBarThemeData(), const SnackBarThemeData().copyWith());
    expect(const SnackBarThemeData().hashCode, const SnackBarThemeData().copyWith().hashCode);
  });

  testWidgets('Passing no SnackBarThemeData returns defaults', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                Scaffold.of(context).showSnackBar(SnackBar(
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          }
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Material material = _getSnackBarMaterial(tester);

    expect(material.color, const Color(0xFF323232));
    expect(material.elevation, 6.0);
    expect(material.shape, null);
  });

  testWidgets('SnackBar uses values from SnackBarThemeData', (WidgetTester tester) async {
    final SnackBarThemeData snackBarTheme = _snackBarTheme();

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(snackBarTheme: snackBarTheme),
      home: Scaffold(
        body: Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () {
                  Scaffold.of(context).showSnackBar(SnackBar(
                    content: const Text('I am a snack bar.'),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                  ));
                },
                child: const Text('X'),
              );
            }
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Material material = _getSnackBarMaterial(tester);
    final RawMaterialButton button = _getSnackBarButton(tester);

    expect(material.color, snackBarTheme.backgroundColor);
    expect(material.elevation, snackBarTheme.elevation);
    expect(material.shape, snackBarTheme.shape);
    expect(button.textStyle.color, snackBarTheme.actionTextColor);
  });

  testWidgets('SnackBar widget properties take priority over theme', (WidgetTester tester) async {
    const Color backgroundColor = Colors.purple;
    const Color textColor = Colors.pink;
    const double elevation = 7.0;
    const ShapeBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(9.0)),
    );

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(snackBarTheme: _snackBarTheme()),
      home: Scaffold(
        body: Builder(
            builder: (BuildContext context) {
              return GestureDetector(
                onTap: () {
                  Scaffold.of(context).showSnackBar(SnackBar(
                    backgroundColor: backgroundColor,
                    elevation: elevation,
                    shape: shape,
                    content: const Text('I am a snack bar.'),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      textColor: textColor,
                      label: 'ACTION',
                      onPressed: () {},
                    ),
                  ));
                },
                child: const Text('X'),
              );
            }
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final Material material = _getSnackBarMaterial(tester);
    final RawMaterialButton button = _getSnackBarButton(tester);

    expect(material.color, backgroundColor);
    expect(material.elevation, elevation);
    expect(material.shape, shape);
    expect(button.textStyle.color, textColor);
  });

  testWidgets('SnackBar theme behavior is correct for floating', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating,)
      ),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.send),
          onPressed: () {},
        ),
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                Scaffold.of(context).showSnackBar(SnackBar(
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final RenderBox snackBarBox = tester.firstRenderObject(find.byType(SnackBar));
    final RenderBox floatingActionButtonBox = tester.firstRenderObject(find.byType(FloatingActionButton));

    final Offset snackBarBottomCenter = snackBarBox.localToGlobal(snackBarBox.size.bottomCenter(Offset.zero));
    final Offset floatingActionButtonTopCenter = floatingActionButtonBox.localToGlobal(floatingActionButtonBox.size.topCenter(Offset.zero));

    // Since padding and margin is handled inside snackBarBox,
    // the bottom offset of snackbar should equal with top offset of FAB
    expect(snackBarBottomCenter.dy == floatingActionButtonTopCenter.dy, true);
  });

  testWidgets('SnackBar theme behavior is correct for fixed', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.fixed,)
      ),
      home: Scaffold(
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.send),
          onPressed: () {},
        ),
        body: Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                Scaffold.of(context).showSnackBar(SnackBar(
                  content: const Text('I am a snack bar.'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(label: 'ACTION', onPressed: () {}),
                ));
              },
              child: const Text('X'),
            );
          },
        ),
      ),
    ));

    final RenderBox floatingActionButtonOriginBox= tester.firstRenderObject(find.byType(FloatingActionButton));
    final Offset floatingActionButtonOriginBottomCenter = floatingActionButtonOriginBox.localToGlobal(floatingActionButtonOriginBox.size.bottomCenter(Offset.zero));

    await tester.tap(find.text('X'));
    await tester.pump(); // start animation
    await tester.pump(const Duration(milliseconds: 750));

    final RenderBox snackBarBox = tester.firstRenderObject(find.byType(SnackBar));
    final RenderBox floatingActionButtonBox = tester.firstRenderObject(find.byType(FloatingActionButton));

    final Offset snackBarTopCenter = snackBarBox.localToGlobal(snackBarBox.size.topCenter(Offset.zero));
    final Offset floatingActionButtonBottomCenter = floatingActionButtonBox.localToGlobal(floatingActionButtonBox.size.bottomCenter(Offset.zero));

    expect(floatingActionButtonOriginBottomCenter.dy > floatingActionButtonBottomCenter.dy, true);
    expect(snackBarTopCenter.dy > floatingActionButtonBottomCenter.dy, true);
  });
}

SnackBarThemeData _snackBarTheme() {
  return SnackBarThemeData(
    backgroundColor: Colors.orange,
    elevation: 12.0,
    shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(12)),
    actionTextColor: Colors.green,
  );
}

Material _getSnackBarMaterial(WidgetTester tester) {
  return tester.widget<Material>(
    find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    ).first,
  );
}

RawMaterialButton _getSnackBarButton(WidgetTester tester) {
  return tester.widget<RawMaterialButton>(
    find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(RawMaterialButton),
    ).first,
  );
}
