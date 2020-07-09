// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'restoration.dart';

void main() {
  testWidgets('claims bucket', (WidgetTester tester) async {
    const RestorationId id = RestorationId('hello world 1234');
    final MockRestorationManager manager = MockRestorationManager();
    final Map<String, dynamic> rawData = <String, dynamic>{};
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: rawData);
    expect(rawData, isEmpty);

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: id,
        ),
      ),
    );
    manager.runFinalizers();

    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, id);
    expect(rawData[childrenMapKey].containsKey(id.value), isTrue);
    expect(state.property.value, 10);
    expect(rawData[childrenMapKey][id.value][valuesMapKey]['foo'], 10);
    expect(state.property.log, <String>['createDefaultValue', 'initWithValue', 'toPrimitives']);
    expect(state.toogleBucketLog, isEmpty);
    expect(state.restoreStateLog.single, isNull);
  });

  testWidgets('claimed bucket with data', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: _createRawDataSet());

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();

    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.property.value, 22);
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
    expect(state.toogleBucketLog, isEmpty);
    expect(state.restoreStateLog.single, isNull);
  });

  testWidgets('renames existing bucket when new ID is provided via widget', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: _createRawDataSet());

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();

    // Claimed existing bucket with data.
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.bucket.get<int>(const RestorationId('foo')), 22);
    final RestorationBucket bucket = state.bucket;

    state.property.log.clear();
    state.restoreStateLog.clear();

    // Rename the existing bucket.
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('something else'),
        ),
      ),
    );
    manager.runFinalizers();

    expect(state.bucket.id, const RestorationId('something else'));
    expect(state.bucket.get<int>(const RestorationId('foo')), 22);
    expect(state.bucket, same(bucket));
    expect(state.property.log, isEmpty);
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog, isEmpty);
  });

  testWidgets('renames existing bucket when didUpdateRestorationId is called', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: _createRawDataSet());

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();

    // Claimed existing bucket with data.
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.bucket.get<int>(const RestorationId('foo')), 22);
    final RestorationBucket bucket = state.bucket;

    state.property.log.clear();
    state.restoreStateLog.clear();

    // Rename the existing bucket.
    state.injectId(const RestorationId('newnewnew'));
    manager.runFinalizers();

    expect(state.bucket.id, const RestorationId('newnewnew'));
    expect(state.bucket.get<int>(const RestorationId('foo')), 22);
    expect(state.bucket, same(bucket));
    expect(state.property.log, isEmpty);
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog, isEmpty);
  });

  testWidgets('Disposing widget removes its data', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final Map<String, dynamic> rawData = _createRawDataSet();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: rawData);

    expect(rawData[childrenMapKey].containsKey('child1'), isTrue);
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();
    expect(rawData[childrenMapKey].containsKey('child1'), isTrue);

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: Container(),
      ),
    );
    manager.runFinalizers();

    expect(rawData[childrenMapKey].containsKey('child1'), isFalse);
  });

  testWidgets('toggling id between null and non-null', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final Map<String, dynamic> rawData = _createRawDataSet();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: rawData);

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: null,
        ),
      ),
    );
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket, isNull);
    expect(state.property.value, 10); // Initialized to default.
    expect(rawData[childrenMapKey]['child1'][valuesMapKey]['foo'], 22);
    expect(state.property.log, <String>['createDefaultValue', 'initWithValue']);
    state.property.log.clear();
    expect(state.restoreStateLog.single, isNull);
    expect(state.toogleBucketLog, isEmpty);
    state.restoreStateLog.clear();
    state.toogleBucketLog.clear();

    // Change id to non-null.
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();
    expect(state.bucket, isNotNull);
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.property.value, 10);
    expect(rawData[childrenMapKey]['child1'][valuesMapKey]['foo'], 10);
    expect(state.property.log, <String>['toPrimitives']);
    state.property.log.clear();
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog.single, isNull);
    state.restoreStateLog.clear();
    state.toogleBucketLog.clear();

    final RestorationBucket bucket = state.bucket;

    // Change id back to null.
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: null,
        ),
      ),
    );
    manager.runFinalizers();
    expect(state.bucket, isNull);
    expect(rawData[childrenMapKey].containsKey('child1'), isFalse);
    expect(state.property.log, isEmpty);
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog.single, same(bucket));
  });

  testWidgets('move in and out of scope', (WidgetTester tester) async {
    final Key key = GlobalKey();
    final MockRestorationManager manager = MockRestorationManager();
    final Map<String, dynamic> rawData = _createRawDataSet();
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: rawData);

    await tester.pumpWidget(
      _TestRestorableWidget(
        key: key,
        restorationId: const RestorationId('child1'),
      ),
    );
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket, isNull);
    expect(state.property.value, 10); // Initialized to default.
    expect(rawData[childrenMapKey]['child1'][valuesMapKey]['foo'], 22);
    expect(state.property.log, <String>['createDefaultValue', 'initWithValue']);
    state.property.log.clear();
    expect(state.restoreStateLog.single, isNull);
    expect(state.toogleBucketLog, isEmpty);
    state.restoreStateLog.clear();
    state.toogleBucketLog.clear();

    // Move it under a valid scope.
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: _TestRestorableWidget(
          key: key,
          restorationId: const RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();
    expect(state.bucket, isNotNull);
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.property.value, 10);
    expect(rawData[childrenMapKey]['child1'][valuesMapKey]['foo'], 10);
    expect(state.property.log, <String>['toPrimitives']);
    state.property.log.clear();
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog.single, isNull);
    state.restoreStateLog.clear();
    state.toogleBucketLog.clear();

    final RestorationBucket bucket = state.bucket;

    // Move out of scope again.
    await tester.pumpWidget(
      _TestRestorableWidget(
        key: key,
        restorationId: const RestorationId('child1'),
      ),
    );
    manager.runFinalizers();
    expect(state.bucket, isNull);
    expect(rawData[childrenMapKey].containsKey('child1'), isFalse);
    expect(state.property.log, isEmpty);
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog.single, same(bucket));
  });

  testWidgets('moving scope moves its data', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    final Map<String, dynamic> rawData = <String, dynamic>{};
    final RestorationBucket root = RestorationBucket.root(manager: manager, rawData: rawData);
    final Key key = GlobalKey();

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: Row(
          textDirection: TextDirection.ltr,
          children: <Widget>[
            RestorationScope(
              restorationId: const RestorationId('fixed'),
              child: _TestRestorableWidget(
                key: key,
                restorationId: const RestorationId('moving-child'),
              ),
            ),
          ],
        ),
      ),
    );
    manager.runFinalizers();
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, const RestorationId('moving-child'));
    expect(rawData[childrenMapKey]['fixed'][childrenMapKey].containsKey('moving-child'), isTrue);
    final RestorationBucket bucket = state.bucket;
    state.property.log.clear();
    state.restoreStateLog.clear();

    state.bucket.put(const RestorationId('value'), 11);
    manager.runFinalizers();

    // Move widget.
    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: Row(
          textDirection: TextDirection.ltr,
          children: <Widget>[
            RestorationScope(
              restorationId: const RestorationId('fixed'),
              child: Container(),
            ),
            _TestRestorableWidget(
              key: key,
              restorationId: const RestorationId('moving-child'),
            ),
          ],
        ),
      ),
    );
    manager.runFinalizers();
    expect(state.bucket.id, const RestorationId('moving-child'));
    expect(state.bucket, same(bucket));
    expect(state.bucket.get<int>(const RestorationId('value')), 11);
    expect(state.property.log, isEmpty);
    expect(state.toogleBucketLog, isEmpty);
    expect(state.restoreStateLog, isEmpty);

    expect(rawData[childrenMapKey]['fixed'], isEmpty);
    expect(rawData[childrenMapKey].containsKey('moving-child'), isTrue);
  });

  testWidgets('decommission claims new bucket with data', (WidgetTester tester) async {
    final MockRestorationManager manager = MockRestorationManager();
    RestorationBucket root = RestorationBucket.root(manager: manager, rawData: <String, dynamic>{});

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );
    manager.runFinalizers();
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.property.value, 10);  // Initialized to default.
    expect(state.bucket.get<int>(const RestorationId('foo')), 10);
    final RestorationBucket bucket = state.bucket;
    state.property.log.clear();
    state.restoreStateLog.clear();

    // Replace root bucket.
    root..decommission()..dispose();
    root = RestorationBucket.root(manager: manager, rawData: _createRawDataSet());

    await tester.pumpWidget(
      UnmanagedRestorationScope(
        bucket: root,
        child: const _TestRestorableWidget(
          restorationId: RestorationId('child1'),
        ),
      ),
    );

    // Bucket has been replaced.
    expect(state.bucket, isNot(same(bucket)));
    expect(state.bucket.id, const RestorationId('child1'));
    expect(state.property.value, 22);  // Restored value.
    expect(state.bucket.get<int>(const RestorationId('foo')), 22);
    expect(state.restoreStateLog.single, bucket);
    expect(state.toogleBucketLog, isEmpty);
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
  });

  testWidgets('restartAndRestore', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      )
    );

    _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.bucket, isNotNull);
    expect(state.property.value, 10); // default
    expect(state.property.log, <String>['createDefaultValue', 'initWithValue', 'toPrimitives']);
    expect(state.restoreStateLog.single, isNull);
    expect(state.toogleBucketLog, isEmpty);
    _clearLogs(state);

    state.setProperties(() {
      state.property.value = 20;
    });
    await tester.pump();
    expect(state.property.value, 20);
    expect(state.property.log, <String>['toPrimitives']);
    expect(state.restoreStateLog, isEmpty);
    expect(state.toogleBucketLog, isEmpty);
    _clearLogs(state);

    final _TestRestorableWidgetState oldState = state;
    await tester.restartAndRestore();
    state = tester.state(find.byType(_TestRestorableWidget));

    expect(state, isNot(same(oldState)));
    expect(state.property.value, 20);
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
    expect(state.restoreStateLog.single, isNull);
    expect(state.toogleBucketLog, isEmpty);
  });

  testWidgets('restore while running', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );

    _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));

    state.setProperties(() {
      state.property.value = 20;
    });
    await tester.pump();
    expect(state.property.value, 20);

    final TestRestorationData data = await tester.getRestorationData();

    state.setProperties(() {
      state.property.value = 30;
    });
    await tester.pump();
    expect(state.property.value, 30);
    _clearLogs(state);

    final _TestRestorableWidgetState oldState = state;
    final RestorationBucket oldBucket = oldState.bucket;
    await tester.restoreFrom(data);
    state = tester.state(find.byType(_TestRestorableWidget));

    expect(state, same(oldState));
    expect(state.property.value, 20);
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
    expect(state.restoreStateLog.single, oldBucket);
    expect(state.toogleBucketLog, isEmpty);
  });

  testWidgets('can register additional property outside of restoreState', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );

    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    state.registerAdditionalProperty();
    expect(state.additionalProperty.value, 11);
    expect(state.additionalProperty.log, <String>['createDefaultValue', 'initWithValue', 'toPrimitives']);

    state.setProperties(() {
      state.additionalProperty.value = 33;
    });
    await tester.pump();
    expect(state.additionalProperty.value, 33);

    final TestRestorationData data = await tester.getRestorationData();

    state.setProperties(() {
      state.additionalProperty.value = 44;
    });
    await tester.pump();
    expect(state.additionalProperty.value, 44);
    _clearLogs(state);

    await tester.restoreFrom(data);

    expect(state, same(tester.state(find.byType(_TestRestorableWidget))));
    expect(state.additionalProperty.value, 33);
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
  });

  testWidgets('cannot register same property twice', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );

    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    state.registerAdditionalProperty();
    await tester.pump();
    expect(() => state.registerAdditionalProperty(), throwsAssertionError);
  });

  testWidgets('cannot register under ID that is already in use', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );

    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    expect(() => state.registerPropertyUnderSameId(), throwsAssertionError);
  });

  testWidgets('data of disabled property is not stored', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );
    _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));

    state.setProperties(() {
      state.property.value = 30;
    });
    await tester.pump();
    expect(state.property.value, 30);
    expect(state.bucket.get<int>(const RestorationId('foo')), 30);
    _clearLogs(state);

    state.setProperties(() {
      state.property.enabled = false;
    });
    await tester.pump();
    expect(state.property.value, 30);
    expect(state.bucket.containsValue(const RestorationId('foo')), isFalse);
    expect(state.property.log, isEmpty);

    state.setProperties(() {
      state.property.value = 40;
    });
    await tester.pump();
    expect(state.bucket.containsValue(const RestorationId('foo')), isFalse);
    expect(state.property.log, isEmpty);

    await tester.restartAndRestore();
    state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.property.log, <String>['createDefaultValue', 'initWithValue', 'toPrimitives']);
    expect(state.property.value, 10); // Initialized to default value.
  });

  testWidgets('Enabling property stores its data again', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );
    _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    _clearLogs(state);

    state.setProperties(() {
      state.property.enabled = false;
    });
    await tester.pump();
    expect(state.bucket.containsValue(const RestorationId('foo')), isFalse);
    state.setProperties(() {
      state.property.value = 40;
    });
    await tester.pump();
    expect(state.property.value, 40);
    expect(state.bucket.containsValue(const RestorationId('foo')), isFalse);
    expect(state.property.log, isEmpty);

    state.setProperties(() {
      state.property.enabled = true;
    });
    await tester.pump();
    expect(state.bucket.get<int>(const RestorationId('foo')), 40);
    expect(state.property.log, <String>['toPrimitives']);

    await tester.restartAndRestore();
    state = tester.state(find.byType(_TestRestorableWidget));
    expect(state.property.log, <String>['fromPrimitives', 'initWithValue']);
    expect(state.property.value, 40);
  });

  testWidgets('Unregistering a property removes its data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    state.registerAdditionalProperty();
    await tester.pump();
    expect(state.additionalProperty.value, 11);
    expect(state.bucket.get<int>(const RestorationId('additional')), 11);
    state.unregisterAdditionalProperty();
    await tester.pump();
    expect(state.bucket.containsValue(const RestorationId('additional')), isFalse);
    expect(() => state.additionalProperty.value, throwsAssertionError); // No longer registered.

    // Can register the same property again.
    state.registerAdditionalProperty();
    await tester.pump();
    expect(state.additionalProperty.value, 11);
    expect(state.bucket.get<int>(const RestorationId('additional')), 11);
  });

  testWidgets('Disposing a property unregisters it, but keeps data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: RestorationId('root-child'),
        child: _TestRestorableWidget(
          restorationId: RestorationId('widget'),
        ),
      ),
    );
    final _TestRestorableWidgetState state = tester.state(find.byType(_TestRestorableWidget));
    state.registerAdditionalProperty();
    await tester.pump();
    expect(state.additionalProperty.value, 11);
    expect(state.bucket.get<int>(const RestorationId('additional')), 11);

    state.additionalProperty.dispose();
    await tester.pump();
    expect(state.bucket.get<int>(const RestorationId('additional')), 11);

    // Can register property under same id again.
    state.additionalProperty = _TestRestorableProperty(22);
    state.registerAdditionalProperty();
    await tester.pump();

    expect(state.additionalProperty.value, 11); // Old value restored.
    expect(state.bucket.get<int>(const RestorationId('additional')), 11);
  });
}

void _clearLogs(_TestRestorableWidgetState state) {
  state.property.log.clear();
  state.additionalProperty?.log?.clear();
  state.restoreStateLog.clear();
  state.toogleBucketLog.clear();
}

class _TestRestorableWidget extends StatefulWidget {

  const _TestRestorableWidget({Key key, this.restorationId}) : super(key: key);

  final RestorationId restorationId;

  @override
  State<_TestRestorableWidget> createState() => _TestRestorableWidgetState();
}

class _TestRestorableWidgetState extends State<_TestRestorableWidget> with RestorationMixin {
  final _TestRestorableProperty property = _TestRestorableProperty(10);
  _TestRestorableProperty additionalProperty;
  bool _rerigisterAdditionalProperty = false;

  final List<RestorationBucket> restoreStateLog = <RestorationBucket>[];
  final List<RestorationBucket> toogleBucketLog = <RestorationBucket>[];


  @override
  void restoreState(RestorationBucket oldBucket) {
    restoreStateLog.add(oldBucket);
    registerForRestoration(property, const RestorationId('foo'));
    if (_rerigisterAdditionalProperty && additionalProperty != null) {
      registerForRestoration(additionalProperty, const RestorationId('additional'));
    }
  }

  @override
  void didToggleBucket(RestorationBucket oldBucket) {
    toogleBucketLog.add(oldBucket);
    super.didToggleBucket(oldBucket);
  }

  @override
  void dispose() {
    super.dispose();
    property.dispose();
    additionalProperty?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  void setProperties(VoidCallback fn) => setState(fn);

  RestorationId _injectedId;
  void injectId(RestorationId id) {
    _injectedId = id;
    didUpdateRestorationId();
  }

  void registerAdditionalProperty({bool reregister = true}) {
    additionalProperty ??= _TestRestorableProperty(11);
    registerForRestoration(additionalProperty, const RestorationId('additional'));
    _rerigisterAdditionalProperty = reregister;
  }

  void unregisterAdditionalProperty() {
    unregisterFromRestoration(additionalProperty);
  }

  void registerPropertyUnderSameId() {
    registerForRestoration(_TestRestorableProperty(11), const RestorationId('foo'));
  }

  @override
  RestorationId get restorationId => _injectedId ?? widget.restorationId;
}

Map<String, dynamic> _createRawDataSet() {
  return <String, dynamic>{
    valuesMapKey: <String, dynamic>{
      'value1' : 10,
      'value2' : 'Hello',
    },
    childrenMapKey: <String, dynamic>{
      'child1' : <String, dynamic>{
        valuesMapKey : <String, dynamic>{
          'foo': 22,
        }
      },
      'child2' : <String, dynamic>{
        valuesMapKey : <String, dynamic>{
          'bar': 33,
        }
      },
    },
  };
}

class _TestRestorableProperty extends RestorableProperty<Object> {
  _TestRestorableProperty(this._value);

  List<String> log = <String>[];

  @override
  bool get enabled => _enabled;
  bool _enabled = true;
  set enabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  @override
  Object createDefaultValue() {
    log.add('createDefaultValue');
    return _value;
  }

  @override
  Object fromPrimitives(Object data) {
    log.add('fromPrimitives');
    return data;
  }

  Object get value {
    assert(isRegistered);
    return _value;
  }
  Object _value;
  set value(Object value) {
    _value = value;
    notifyListeners();
  }

  @override
  void initWithValue(Object v) {
    log.add('initWithValue');
    _value = v;
  }

  @override
  Object toPrimitives() {
    log.add('toPrimitives');
    return _value;
  }
}
