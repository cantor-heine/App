// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@protocol NativeViewControllerDelegate

/// Triggered when the increment button from the NativeViewController is tapped.
- (void)didTapIncrementButton;

@end

@interface NativeViewController : UIViewController

- (instancetype)initWithDelegate:(nullable id<NativeViewControllerDelegate>)delegate NS_DESIGNATED_INITIALIZER;

@property(nonatomic, weak) id<NativeViewControllerDelegate> delegate;

- (void)didReceiveIncrement;

@end

NS_ASSUME_NONNULL_END
