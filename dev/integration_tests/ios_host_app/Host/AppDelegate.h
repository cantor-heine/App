// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import UIKit;
@import Flutter;

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : FlutterAppDelegate

@property(readonly, nullable) FlutterEngine* engine;
@property(readonly, nullable) FlutterBasicMessageChannel* reloadMessageChannel;

@end

NS_ASSUME_NONNULL_END
