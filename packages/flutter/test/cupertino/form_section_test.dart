// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';

void main() {
  testWidgets('Shows header', (WidgetTester tester) async {
    const Widget header = Text('Enter Value');

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection(
            header: header,
            children: [CupertinoTextFormFieldRow()],
          ),
        ),
      ),
    );

    expect(header, tester.widget(find.byType(Text)));
  });

  testWidgets('Shows long dividers in edge-to-edge section part 1',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection(
            children: <Widget>[CupertinoTextFormFieldRow()],
          ),
        ),
      ),
    );

    // Since the children list is reconstructed with dividers in it, the column
    // retrieved should have 3 items for an input [children] param with 1 child.
    final Column childrenColumn = tester.widget(find.byType(Column).at(1));
    expect(childrenColumn.children.length, 3);
  });

  testWidgets('Shows long dividers in edge-to-edge section part 2',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection(
            children: <Widget>[
              CupertinoTextFormFieldRow(),
              CupertinoTextFormFieldRow()
            ],
          ),
        ),
      ),
    );

    // Since the children list is reconstructed with dividers in it, the column
    // retrieved should have 5 items for an input [children] param with 2
    // children. Two long dividers, two rows, and one short divider.
    final Column childrenColumn = tester.widget(find.byType(Column).at(1));
    expect(childrenColumn.children.length, 5);
  });

  testWidgets('Does not show long dividers in insetGrouped section part 1',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection.insetGrouped(
            children: <Widget>[CupertinoTextFormFieldRow()],
          ),
        ),
      ),
    );

    // Since the children list is reconstructed without long dividers in it, the
    // column retrieved should have 1 item for an input [children] param with 1
    // child.
    final Column childrenColumn = tester.widget(find.byType(Column).at(1));
    expect(childrenColumn.children.length, 1);
  });

  testWidgets('Does not show long dividers in insetGrouped section part 2',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        restorationScopeId: 'App',
        home: Center(
          child: CupertinoFormSection.insetGrouped(
            children: <Widget>[
              CupertinoTextFormFieldRow(),
              CupertinoTextFormFieldRow()
            ],
          ),
        ),
      ),
    );

    // Since the children list is reconstructed with short dividers in it, the
    // column retrieved should have 3 items for an input [children] param with 2
    // children. Two long dividers, two rows, and one short divider.
    final Column childrenColumn = tester.widget(find.byType(Column).at(1));
    expect(childrenColumn.children.length, 3);
  });

  testWidgets('Sets background color for section', (WidgetTester tester) async {
    const Color backgroundColor = CupertinoColors.systemBlue;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: CupertinoFormSection(
            children: <Widget>[CupertinoTextFormFieldRow()],
            backgroundColor: backgroundColor,
          ),
        ),
      ),
    );

    final DecoratedBox decoratedBox =
        tester.widget(find.byType(DecoratedBox).first);
    final BoxDecoration boxDecoration =
        decoratedBox.decoration as BoxDecoration;
    expect(boxDecoration.color, backgroundColor);
  });

  testWidgets('Setting clipBehavior clips children section',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection(
            children: <Widget>[CupertinoTextFormFieldRow()],
            clipBehavior: Clip.antiAlias,
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsOneWidget);
  });

  testWidgets('Not setting clipBehavior does not clip children section',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: CupertinoFormSection(
            children: <Widget>[CupertinoTextFormFieldRow()],
          ),
        ),
      ),
    );

    expect(find.byType(ClipRRect), findsNothing);
  });
}
