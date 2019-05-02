// Copyright 2019-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:io';
import 'dart:ui' show lerpDouble;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'barcode_scanner_utils.dart';
import 'colors.dart';

class BarcodeScanner extends StatefulWidget {
  const BarcodeScanner(this.validSquareWidth);

  final double validSquareWidth;

  @override
  _BarcodeScannerState createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner>
    with TickerProviderStateMixin {
  CameraController _controller;
  String _scannerHint;
  bool _closeWindow = false;
  String _barcodePictureFilePath;
  Color _frameColor = Colors.white54;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _barcodeFound = false;

  AnimationController _squareAnimation;
  SquareTween _squareTween;
  Timer _squareAnimationTimer;

  Tween<double> _squareTraceTween;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIOverlays(<SystemUiOverlay>[]);
    _startScanningBarcodes();
    _squareAnimation = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );

    _squareTraceTween = Tween<double>(
      begin: 0,
      end: widget.validSquareWidth,
    );

    _squareTween = SquareTween(
      Square(widget.validSquareWidth, Colors.white),
      Square(widget.validSquareWidth + 100, Colors.transparent),
    );

    _squareAnimation.forward();
    _squareAnimationTimer = Timer.periodic(
      Duration(milliseconds: 3000),
      (_) => _squareAnimation.forward(from: 0),
    );
  }

  void _handleBarcodeFound() {
    setState(() {
      _barcodeFound = true;
      _scannerHint = 'Loading information...';
      _closeWindow = true;
      _frameColor = Colors.black87;
    });
  }

  Future<void> _startScanningBarcodes() async {
    final CameraDescription camera = await getCamera(CameraLensDirection.back);
    await _openCamera(camera);
    await _streamImages(camera.sensorOrientation);
  }

  Future<void> _openCamera(CameraDescription camera) async {
    final ResolutionPreset preset =
        defaultTargetPlatform == TargetPlatform.android
            ? ResolutionPreset.medium
            : ResolutionPreset.low;

    _controller = CameraController(camera, preset);
    await _controller.initialize();

    setState(() {});
  }

  Future<void> _streamImages(int sensorOrientation) async {
    final BarcodeDetector detector = FirebaseVision.instance.barcodeDetector();
    bool isDetecting = false;
    final Size size = MediaQuery.of(context).size;

    _controller.startImageStream((CameraImage image) {
      if (isDetecting) {
        return;
      }

      isDetecting = true;

      final ImageRotation rotation = rotationIntToImageRotation(
        sensorOrientation,
      );

      detect(image, detector.detectInImage, rotation).then(
        (dynamic result) {
          if (!_controller.value.isStreamingImages) {
            return;
          }

          final double widthScale = image.height / size.width;
          final double heightScale = image.width / size.height;

          final Offset center = size.center(Offset.zero);
          final double halfRectSideLength = widget.validSquareWidth / 2;

          final Rect validRect = Rect.fromLTWH(
            widthScale * (center.dx - halfRectSideLength),
            heightScale * (center.dy - halfRectSideLength),
            widthScale * widget.validSquareWidth,
            heightScale * widget.validSquareWidth,
          );

          final List<Barcode> barcodes = result;
          if (barcodes.isNotEmpty) {
            for (Barcode barcode in barcodes) {
              final Rect intersection =
                  validRect.intersect(barcode.boundingBox);

              final bool doesContain = intersection == barcode.boundingBox;

              if (doesContain) {
                _controller.stopImageStream().then((_) {
                  _takePicture();
                });

                _handleBarcodeFound();

                _squareAnimationTimer.cancel();
                _squareAnimationTimer = null;

                _squareAnimation.duration = Duration(milliseconds: 2000);

                _squareAnimation.addStatusListener((AnimationStatus status) {
                  if (status == AnimationStatus.completed) {
                    _showBottomSheet();
                  }
                });

                _squareAnimation.forward(from: 0);
                return;
              } else if (validRect.overlaps(barcode.boundingBox)) {
                setState(() {
                  _scannerHint = 'Move closer to the barcode';
                });
                return;
              }
            }
          }

          setState(() {
            _scannerHint = null;
          });
        },
      ).whenComplete(() => isDetecting = false);
    });
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _squareAnimation?.dispose();
    _squareAnimationTimer?.cancel();
    SystemChrome.setEnabledSystemUIOverlays(<SystemUiOverlay>[
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ]);
    super.dispose();
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _takePicture() async {
    final Directory extDir = await getApplicationDocumentsDirectory();

    final String dirPath = '${extDir.path}/Pictures/barcodePics';
    await Directory(dirPath).create(recursive: true);

    final String filePath = '$dirPath/${_timestamp()}.jpg';

    try {
      await _controller.takePicture(filePath);
    } on CameraException catch (e) {
      print(e);
    }

    _controller.dispose();
    _controller = null;

    setState(() {
      _barcodePictureFilePath = filePath;
    });
  }

  Widget _buildCameraPreview() {
    final Size size = MediaQuery.of(context).size;
    final double deviceRatio = size.width / size.height;

    return Transform.scale(
      scale: _controller.value.aspectRatio / deviceRatio,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: CameraPreview(_controller),
        ),
      ),
    );
  }

  void _showBottomSheet() {
    final PersistentBottomSheetController<void> controller =
        _scaffoldKey.currentState.showBottomSheet<void>(
      (BuildContext context) {
        return Container(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                alignment: Alignment.topLeft,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('1 result found'),
                ),
              ),
              Container(
                margin: EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Image.asset(
                          '18-0.jpg',
                          package: 'shrine_images',
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                        ),
                        Container(
                          height: 96,
                          margin: EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                child: Text(
                                  'Medium Red Notepad',
                                  style: Theme.of(context)
                                      .textTheme
                                      .body1
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                '(2 pack)',
                                style: Theme.of(context)
                                    .textTheme
                                    .body1
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: const <Widget>[
                                    Text('A5, ruled'),
                                    Text('100 pages'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 22, bottom: 25),
                      child: Text(
                        'Lightweight yet durable notepad with red leather'
                        'cover for everyday notes. Available in packs of 2.',
                      ),
                    ),
                    RaisedButton(
                      onPressed: () {},
                      color: kShrinePink100,
                      child: Container(
                        width: 312,
                        height: 48,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              margin: EdgeInsets.only(right: 16),
                              child: Icon(Icons.add_shopping_cart),
                            ),
                            Text('ADD TO CART - \$39.99',
                                style:
                                    Theme.of(context).primaryTextTheme.button),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );

    controller.closed.then((_) => Navigator.of(context).pop());
  }

  @override
  Widget build(BuildContext context) {
    Widget background;
    if (_barcodePictureFilePath != null) {
      background = Container(
        constraints: BoxConstraints.expand(),
        child: Image.file(
          File(_barcodePictureFilePath),
          fit: BoxFit.fill,
        ),
      );
    } else if (_controller != null && _controller.value.isInitialized) {
      background = _buildCameraPreview();
    } else {
      background = Container(
        color: Colors.black,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: <Widget>[
          background,
          Container(
            constraints: BoxConstraints.expand(),
            child: CustomPaint(
              painter: WindowPainter(
                windowSize:
                    Size(widget.validSquareWidth, widget.validSquareWidth),
                windowFrameColor: _frameColor,
                closeWindow: _closeWindow,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const <Color>[Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.0,
            bottom: 0.0,
            right: 0.0,
            height: 56,
            child: Container(
              color: kShrinePink50,
              child: Center(
                child: Text(
                  _scannerHint ?? 'Point your camera at a barcode',
                  style: Theme.of(context)
                      .textTheme
                      .body1
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints.expand(),
            child: Center(
              child: Container(
                width: widget.validSquareWidth,
                height: widget.validSquareWidth,
                decoration: BoxDecoration(
                  border: Border.all(width: 3, color: kShrineBrown600),
                ),
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints.expand(),
            child: _squareAnimationTimer != null && _squareAnimation != null
                ? CustomPaint(
                    painter: SquarePainter(
                      _squareTween.animate(_squareAnimation),
                    ),
                  )
                : null,
          ),
          Container(
            constraints: BoxConstraints.expand(),
            child: _barcodeFound
                ? CustomPaint(
                    painter: SquareTracePainter(
                      animation: _squareTraceTween.animate(
                        _squareAnimation,
                      ),
                      square: Square(widget.validSquareWidth, Colors.white),
                    ),
                  )
                : null,
          ),
          AppBar(
            leading: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
            actions: <Widget>[
              IconButton(
                icon: Icon(
                  Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  Icons.help_outline,
                  color: Colors.white,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WindowPainter extends CustomPainter {
  WindowPainter({
    @required this.windowSize,
    @required this.windowFrameColor,
    this.closeWindow = false,
  });

  final Size windowSize;
  final Color windowFrameColor;
  final bool closeWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double windowHalfWidth = windowSize.width / 2;
    final double windowHalfHeight = windowSize.height / 2;

    final Rect windowRect = Rect.fromLTRB(
      center.dx - windowHalfWidth,
      center.dy - windowHalfHeight,
      center.dx + windowHalfWidth,
      center.dy + windowHalfHeight,
    );

    final Rect left =
        Rect.fromLTRB(0, windowRect.top, windowRect.left, windowRect.bottom);
    final Rect top = Rect.fromLTRB(0, 0, size.width, windowRect.top);
    final Rect right = Rect.fromLTRB(
      windowRect.right,
      windowRect.top,
      size.width,
      windowRect.bottom,
    );
    final Rect bottom = Rect.fromLTRB(
      0,
      windowRect.bottom,
      size.width,
      size.height,
    );

    final Paint paint = Paint()..color = windowFrameColor;
    canvas.drawRect(left, paint);
    canvas.drawRect(top, paint);
    canvas.drawRect(right, paint);
    canvas.drawRect(bottom, paint);

    if (closeWindow) {
      canvas.drawRect(windowRect, paint);
    }
  }

  @override
  bool shouldRepaint(WindowPainter oldDelegate) =>
      oldDelegate.closeWindow != closeWindow;
}

class Square {
  Square(this.width, this.color);

  final double width;
  final Color color;

  static Square lerp(Square begin, Square end, double t) {
    Color color;
    if (t > 0.75) {
      color = Color.lerp(begin.color, end.color, (t - .75) / .25);
    } else {
      color = begin.color;
    }

    return Square(lerpDouble(begin.width, end.width, t), color);
  }
}

class SquareTween extends Tween<Square> {
  SquareTween(Square begin, Square end) : super(begin: begin, end: end);

  @override
  Square lerp(double t) => Square.lerp(begin, end, t);
}

class SquarePainter extends CustomPainter {
  SquarePainter(this.animation) : super(repaint: animation);

  final Animation<Square> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final Square square = animation.value;

    final Paint paint = Paint()
      ..strokeWidth = 3
      ..color = square.color
      ..style = PaintingStyle.stroke;

    final Offset center = size.center(Offset.zero);
    final double halfWidth = square.width / 2;

    final Rect rect = Rect.fromLTRB(
      center.dx - halfWidth,
      center.dy - halfWidth,
      center.dx + halfWidth,
      center.dy + halfWidth,
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(SquarePainter oldDelegate) => false;
}

class SquareTracePainter extends CustomPainter {
  SquareTracePainter({this.animation, this.square}) : super(repaint: animation);

  final Animation<double> animation;
  final Square square;

  @override
  void paint(Canvas canvas, Size size) {
    final double value = animation.value;

    final Offset center = size.center(Offset.zero);
    final double halfWidth = square.width / 2;

    final Rect rect = Rect.fromLTRB(
      center.dx - halfWidth,
      center.dy - halfWidth,
      center.dx + halfWidth,
      center.dy + halfWidth,
    );

    final Paint paint = Paint()
      ..strokeWidth = 3
      ..color = square.color;

    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right, rect.top + (square.width - value)),
      paint,
    );

    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.left + (square.width - value), rect.bottom),
      paint,
    );

    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left, rect.top + value),
      paint,
    );

    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left + value, rect.top),
      paint,
    );
  }

  @override
  bool shouldRepaint(SquareTracePainter oldDelegate) => false;
}
