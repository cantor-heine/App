// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class _DebugOnly {
  const _DebugOnly();
}

const _DebugOnly _debugOnly = _DebugOnly();
const bool kDebugMode = bool.fromEnvironment('test-only');

class Foo {
  @_debugOnly
  final Map<String, String>? foo = kDebugMode ? <String, String>{} : null;

  @_debugOnly
  final Map<String, String>? bar = kDebugMode ? null : <String, String>{};
}
