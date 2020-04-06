// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../text.dart' show findRenderEditable, globalize, textOffsetToPosition;

void main() {
  group('canSelectAll', () {
    Widget createEditableText({
      Key key,
      String text,
      TextSelection selection,
    }) {
      final TextEditingController controller = TextEditingController(text: text)
        ..selection = selection ?? const TextSelection.collapsed(offset: -1);
      return MaterialApp(
        home: EditableText(
          key: key,
          controller: controller,
          focusNode: FocusNode(),
          style: const TextStyle(),
          cursorColor: Colors.black,
          backgroundCursorColor: Colors.black,
        ),
      );
    }

    testWidgets('should return false when there is no text', (WidgetTester tester) async {
      final GlobalKey<EditableTextState> key = GlobalKey();
      await tester.pumpWidget(createEditableText(key: key));
      expect(materialTextSelectionControls.canSelectAll(key.currentState), false);
    });

    testWidgets('should return true when there is text and collapsed selection', (WidgetTester tester) async {
      final GlobalKey<EditableTextState> key = GlobalKey();
      await tester.pumpWidget(createEditableText(
        key: key,
        text: '123',
      ));
      expect(materialTextSelectionControls.canSelectAll(key.currentState), true);
    });

    testWidgets('should return true when there is text and partial uncollapsed selection', (WidgetTester tester) async {
      final GlobalKey<EditableTextState> key = GlobalKey();
      await tester.pumpWidget(createEditableText(
        key: key,
        text: '123',
        selection: const TextSelection(baseOffset: 1, extentOffset: 2),
      ));
      expect(materialTextSelectionControls.canSelectAll(key.currentState), true);
    });

    testWidgets('should return false when there is text and full selection', (WidgetTester tester) async {
      final GlobalKey<EditableTextState> key = GlobalKey();
      await tester.pumpWidget(createEditableText(
        key: key,
        text: '123',
        selection: const TextSelection(baseOffset: 0, extentOffset: 3),
      ));
      expect(materialTextSelectionControls.canSelectAll(key.currentState), false);
    });
  });

  group('Text selection menu overflow (Android)', () {
    testWidgets('All menu items show when they fit.', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'abc def ghi');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(800.0, 600.0)),
              child: Center(
                child: Material(
                  child: TextField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Tap to place the cursor in the field, then tap the handle to show the
      // selection menu.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final RenderEditable renderEditable = findRenderEditable(tester);
      final List<TextSelectionPoint> endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      expect(endpoints.length, 1);
      final Offset handlePos = endpoints[0].point + const Offset(0.0, 1.0);
      await tester.tapAt(handlePos, pointer: 7);
      await tester.pump();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);

      // Long press to select a word and show the full selection menu.
      final Offset textOffset = textOffsetToPosition(tester, 1);
      await tester.longPressAt(textOffset);
      await tester.pump();
      await tester.pump();

      // The full menu is shown without the more button.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));

    testWidgets('When menu items don\'t fit, an overflow menu is used.', (WidgetTester tester) async {
      // Set the screen size to more narrow, so that SELECT ALL can't fit.
      tester.binding.window.physicalSizeTestValue = const Size(1000, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final TextEditingController controller = TextEditingController(text: 'abc def ghi');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 600.0)),
            child: Center(
              child: Material(
                child: TextField(
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Long press to show the menu.
      final Offset textOffset = textOffsetToPosition(tester, 1);
      await tester.longPressAt(textOffset);
      await tester.pumpAndSettle();

      // The last button is missing, and a more button is shown.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
      final Offset cutOffset = tester.getTopLeft(find.text('CUT'));

      // Tapping the button shows the overflow menu.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // The back button is at the bottom of the overflow menu.
      final Offset selectAllOffset = tester.getTopLeft(find.text('SELECT ALL'));
      final Offset moreOffset = tester.getTopLeft(find.byType(IconButton));
      expect(moreOffset.dy, greaterThan(selectAllOffset.dy));

      // The overflow menu grows upward.
      expect(selectAllOffset.dy, lessThan(cutOffset.dy));

      // Tapping the back button shows the selection menu again.
      expect(find.byType(IconButton), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));

    testWidgets('A smaller menu bumps more items to the overflow menu.', (WidgetTester tester) async {
      // Set the screen size so narrow that only CUT and COPY can fit.
      tester.binding.window.physicalSizeTestValue = const Size(800, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final TextEditingController controller = TextEditingController(text: 'abc def ghi');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 600.0)),
            child: Center(
              child: Material(
                child: TextField(
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Long press to show the menu.
      final Offset textOffset = textOffsetToPosition(tester, 1);
      await tester.longPressAt(textOffset);
      await tester.pump();

      // The last two buttons are missing, and a more button is shown.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);

      // Tapping the button shows the overflow menu, which contains both buttons
      // missing from the main menu, and a back button.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Tapping the back button shows the selection menu again.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));

    testWidgets('When the menu renders below the text, the overflow menu back button is at the top.', (WidgetTester tester) async {
      // Set the screen size to more narrow, so that SELECT ALL can't fit.
      tester.binding.window.physicalSizeTestValue = const Size(1000, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final TextEditingController controller = TextEditingController(text: 'abc def ghi');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 600.0)),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                child: TextField(
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Long press to show the menu.
      final Offset textOffset = textOffsetToPosition(tester, 1);
      await tester.longPressAt(textOffset);
      await tester.pump();

      // The last button is missing, and a more button is shown.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
      final Offset cutOffset = tester.getTopLeft(find.text('CUT'));

      // Tapping the button shows the overflow menu.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // The back button is at the top of the overflow menu.
      final Offset selectAllOffset = tester.getTopLeft(find.text('SELECT ALL'));
      final Offset moreOffset = tester.getTopLeft(find.byType(IconButton));
      expect(moreOffset.dy, lessThan(selectAllOffset.dy));

      // The overflow menu grows downward.
      expect(selectAllOffset.dy, greaterThan(cutOffset.dy));

      // Tapping the back button shows the selection menu again.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));

    testWidgets('When the menu items change, the menu is closed and _closedWidth reset.', (WidgetTester tester) async {
      // Set the screen size to more narrow, so that SELECT ALL can't fit.
      tester.binding.window.physicalSizeTestValue = const Size(1000, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      final TextEditingController controller = TextEditingController(text: 'abc def ghi');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 600.0)),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                child: TextField(
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Tap to place the cursor and tap again to show the menu without a
      // selection.
      await tester.tapAt(textOffsetToPosition(tester, 0));
      await tester.pumpAndSettle();
      final RenderEditable renderEditable = findRenderEditable(tester);
      final List<TextSelectionPoint> endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      expect(endpoints.length, 1);
      final Offset handlePos = endpoints[0].point + const Offset(0.0, 1.0);
      await tester.tapAt(handlePos, pointer: 7);
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);

      // Tap SELECT ALL and measure the usual position of CUT, without
      // _closedWidth having been used yet.
      await tester.tap(find.text('SELECT ALL'));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      final Offset cutOffset = tester.getTopLeft(find.text('CUT'));

      // Tap to clear the selection.
      await tester.tapAt(textOffsetToPosition(tester, 0));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Long press to show the menu.
      await tester.longPressAt(textOffsetToPosition(tester, 1));
      await tester.pump();

      // The last button is missing, and a more button is shown.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsOneWidget);

      // Tapping the button shows the overflow menu.
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Tapping SELECT ALL changes the menu items so that there is no no longer
      // any overflow.
      await tester.tap(find.text('SELECT ALL'));
      await tester.pumpAndSettle();
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      final Offset newCutOffset = tester.getTopLeft(find.text('CUT'));
      expect(newCutOffset, equals(cutOffset));
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));
  });

  group('menu position', () {
    testWidgets('When renders below a block of text, menu appears below bottom endpoint', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController(text: 'abc\ndef\nghi\njkl\nmno\npqr');
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 600.0)),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                child: TextField(
                  controller: controller,
                ),
              ),
            ),
          ),
        ),
      ));

      // Initially, the menu isn't shown at all.
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsNothing);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // Tap to place the cursor in the field, then tap the handle to show the
      // selection menu.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      RenderEditable renderEditable = findRenderEditable(tester);
      List<TextSelectionPoint> endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      expect(endpoints.length, 1);
      final Offset handlePos = endpoints[0].point + const Offset(0.0, 1.0);
      await tester.tapAt(handlePos, pointer: 7);
      await tester.pump();
      expect(find.text('CUT'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);

      // Tap to select all.
      await tester.tap(find.text('SELECT ALL'));
      await tester.pumpAndSettle();

      // Only CUT, COPY, and PASTE are shown.
      expect(find.text('CUT'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('PASTE'), findsOneWidget);
      expect(find.text('SELECT ALL'), findsNothing);
      expect(find.byType(IconButton), findsNothing);

      // The menu appears below the bottom handle.
      renderEditable = findRenderEditable(tester);
      endpoints = globalize(
        renderEditable.getEndpointsForSelection(controller.selection),
        renderEditable,
      );
      expect(endpoints.length, 2);
      final Offset bottomHandlePos = endpoints[1].point;
      final Offset cutOffset = tester.getTopLeft(find.text('CUT'));
      expect(cutOffset.dy, greaterThan(bottomHandlePos.dy));
    }, skip: isBrowser, variant: const TargetPlatformVariant(<TargetPlatform>{ TargetPlatform.android }));
  });

  group('material handles', () {
    testWidgets('draws transparent handle correctly', (WidgetTester tester) async {
      await tester.pumpWidget(RepaintBoundary(
        child: Theme(
          data: ThemeData(
            textSelectionHandleColor: const Color(0x550000AA),
          ),
          isMaterialAppTheme: true,
          child: Builder(
            builder: (BuildContext context) {
              return Container(
                color: Colors.white,
                height: 800,
                width: 800,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 250),
                  child: FittedBox(
                    child: materialTextSelectionControls.buildHandle(
                      context, TextSelectionHandleType.right, 10.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ));

      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('transparent_handle.png'),
      );
    });
  });
}
