/*import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image/image.dart' as image;

import 'package:ngfee/common/util.dart';

class GoogleMapUtil {
  static final GoogleMapUtil _singleton = new GoogleMapUtil._internal();
  factory GoogleMapUtil() {
    return _singleton;
  }

  GoogleMapUtil._internal() {}

  Map<String, BitmapDescriptor> _iconMap = {};
  Map<String, ui.Image> _imageMap = {};
  Map<String, BitmapDescriptor> _bitmapMap = {};

  LatLngBounds _createBounds(List<LatLng> positions) {
    final southwestLat = positions.map((p) => p.latitude).reduce(
        (value, element) => value < element ? value : element); // smallest
    final southwestLon = positions
        .map((p) => p.longitude)
        .reduce((value, element) => value < element ? value : element);
    final northeastLat = positions.map((p) => p.latitude).reduce(
        (value, element) => value > element ? value : element); // biggest
    final northeastLon = positions
        .map((p) => p.longitude)
        .reduce((value, element) => value > element ? value : element);
    return LatLngBounds(
        southwest: LatLng(southwestLat, southwestLon),
        northeast: LatLng(northeastLat, northeastLon));
  }

  LatLngBounds bounds(Set<Marker> markers) {
    if (markers == null || markers.isEmpty) return null;
    return _createBounds(markers.map((m) => m.position).toList());
  }

  // imageWidth가 null이면 원본의 이미지 크기를 사용하여 스케일
  // 값이 주어지면 그 값을 이용하여 스케일
  Future<Uint8List> _getBytesFromAsset(String assetPath,
      {double imageWidth}) async {
    ByteData data = await rootBundle.load(assetPath);

    if (imageWidth == null) {
      image.Image baseSizeImage = image.decodeImage(data.buffer.asUint8List());
      imageWidth = baseSizeImage.width.toDouble();
    }
    int iconWidth = (imageWidth * (Util.pixelRatio / 3.0)).toInt();

    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: iconWidth);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  Future<BitmapDescriptor> loadAssetIcon(String assetPath,
      {double width}) async {
    String path = assetPath + (width ?? 0).toString();
    if (_iconMap[path] == null) {
      Uint8List bytes = await _getBytesFromAsset(assetPath, imageWidth: width);
      if (bytes != null) {
        _iconMap[path] = BitmapDescriptor.fromBytes(bytes);
        print('loadAssetIcon: $assetPath loaded');
      } else {
        print('loadAssetIcon: $assetPath not found');
        return null;
      }
    }
    return _iconMap[path];
  }

  BitmapDescriptor findAssetIcon(String assetPath) {
    return _iconMap[assetPath];
  }

  Future<ui.Image> loadUiImage(String imageAssetPath) async {
    if (_imageMap[imageAssetPath] == null) {
      final ByteData data = await rootBundle.load(imageAssetPath);
      if (data != null) {
        double pinScale = (Util.pixelRatio / 3.0);

        image.Image baseSizeImage =
            image.decodeImage(data.buffer.asUint8List());
        image.Image resizeImage = image.copyResize(baseSizeImage,
            height: (baseSizeImage.height * pinScale).toInt(),
            width: (baseSizeImage.width * pinScale).toInt());
        ui.Codec codec =
            await ui.instantiateImageCodec(image.encodePng(resizeImage));
        ui.FrameInfo frameInfo = await codec.getNextFrame();
        _imageMap[imageAssetPath] = frameInfo.image;
      } else {
        print('loadUiImage: $imageAssetPath not found');
      }
    }
    return _imageMap[imageAssetPath];
  }

  void _drawText(Canvas c, String text, TextStyle style,
      {Size boxSize, TextAlign align, Offset ofs}) {
    TextSpan span = new TextSpan(
      style: style,
      text: text,
    );

    TextPainter tp = new TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );

    // 그려줌 (위치 알 수 있음)
    tp.layout();

    double x = ofs?.dx ?? 0;
    double y = ofs?.dy ?? 0;
    if (boxSize != null) {
      if (boxSize.width != null) {
        if (align == TextAlign.center)
          x = boxSize.width / 2 - tp.width / 2;
        else if (align == TextAlign.right) {
          x = boxSize.width - tp.width;
        }
      }
    }
    tp.paint(c, Offset(x, y));
  }

  void _drawMoneyRangeText(Canvas c, List<String> texts, double width,
      double height, double pinScale,
      {double offsetY = 0}) {
    double dx = 0, dy = 0;
    int lines = texts.length;
    for (var i = 0; i < lines; i++) {
      TextSpan span = new TextSpan(
        style: new TextStyle(
          color: Colors.black,
          fontSize: (i == 0 ? 45.0 : 37.0) * pinScale,
          fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
        ),
        text: texts[i],
      );

      TextPainter tp = new TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      if (i == 0) {
        dx = width / 2 - tp.width / 2;
        if (lines == 1)
          dy = height / 2 - tp.height / 2;
        else
          dy = 0;
      } else {
        dx = width - (tp.width + 4);
      }
      tp.paint(c, new Offset(dx, dy + offsetY));

      dy += tp.height / 2 + 20 * pinScale;
    }
  }

  void _drawMultiLineTexts(Canvas c, List<String> texts, double width,
      double height, double pinScale,
      {TextStyle commonStyle,
      List<TextStyle> styles,
      TextAlign align,
      Offset ofs}) {
    double dx = 0, dy = 0;
    for (var i = 0; i < texts.length; i++) {
      TextPainter tp = new TextPainter(
        text: TextSpan(
          text: texts[i],
          style: commonStyle ??
              (styles != null
                  ? styles[i]
                  : TextStyle(
                      color: Colors.black,
                      fontSize: 45 * pinScale,
                      fontWeight: FontWeight.bold,
                    )),
        ),
        textDirection: TextDirection.ltr,
      );

      tp.layout();

      if (align == TextAlign.center) {
        dx = width / 2 - tp.width / 2;
      } else if (align == TextAlign.right) {
        dx = width - (tp.width + (ofs?.dx ?? 0));
      } else if (align == TextAlign.left) {
        dx = (ofs?.dx ?? 0);
      }

      var paintOffset = new Offset(dx, (dy + (ofs?.dy ?? 0)));
      tp.paint(c, paintOffset);

      //print('${texts[i]}: $height, ${paintOffset.dx}, ${paintOffset.dy}');

      dy += tp.height - 5;
    }
  }

  // Here it is!
  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  Future<BitmapDescriptor> createPinBitmap(String imagePath) async {
    if (_bitmapMap.containsKey(imagePath)) {
      return _bitmapMap[imagePath];
    } else {
      var bitmap = await BitmapDescriptor.fromAssetImage(
          ImageConfiguration(devicePixelRatio: Util.pixelRatio), imagePath);
      _bitmapMap[imagePath] = bitmap;
      return bitmap;
    }
  }

  Offset drawBox(Canvas c, Size size,
      {bool rounded, Color roundColor, double borderWidth}) {
    if (rounded == true) {
      c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(0, 0, size.width, size.height),
              Radius.circular(40.0)),
          Paint()
            ..color = roundColor
            ..style = PaintingStyle.fill
            ..strokeCap = StrokeCap.round);

      double lineWidth = borderWidth ?? 6;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(lineWidth, lineWidth, size.width - lineWidth,
                  size.height - lineWidth),
              Radius.circular(35.0)),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill
            ..strokeCap = StrokeCap.round);
      return Offset(20, 12);
    } else {
      // box
      c.drawRect(
          Rect.fromLTRB(0, 0, size.width, size.height),
          Paint()
            ..color = Colors.orange
            ..style = PaintingStyle.fill
            ..strokeCap = StrokeCap.round);
      // box shadow
      c.drawRect(
          Rect.fromLTRB(0, 0, size.width, size.height),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
      return Offset(10, 2);
    }
  }

  Future drawImage(
      Canvas c, Size size, String imagePath, Size imageSize) async {
    ui.Image _iconImage = await loadUiImage(imagePath);
    var srcrc = Rect.fromLTRB(
        0, 0, _iconImage.width.toDouble(), _iconImage.height.toDouble());
    double dstx = (size.width - imageSize.width) / 2;
    double dsty = size.height - imageSize.height;
    var dstrc = Rect.fromLTRB(
        dstx, dsty, dstx + imageSize.width, dsty + imageSize.height);
    c.drawImageRect(_iconImage, srcrc, dstrc, new Paint());
  }

  Future<BitmapDescriptor> createHouseBitmap(List<String> prices, int count,
      {String bgImagePath,
      bool rounded,
      String title,
      Offset imageOffset = Offset.zero,
      Color roundColor = Colors.blue,
      Color countTextColor = Colors.black}) async {
    String bitmapKey = [
      prices.join(','),
      (title ?? ''),
      count.toString(),
      roundColor.value.toString(),
      countTextColor.value.toString(),
      (bgImagePath ?? '')
    ].join('-');

    if (_bitmapMap.containsKey(bitmapKey)) {
      return _bitmapMap[bitmapKey];
    }

    double textWidth = 120; // 최소 텍스트 크기
    double textHeight = 20; // 시작 텍스트 높이

    // 그려줄 텍스트 스타일 지정
    List<TextStyle> textStyles = [
      // money
      TextStyle(
        color: Colors.black,
        fontSize: 36,
        fontWeight: FontWeight.bold,
      ),
      // title
      TextStyle(
        color: Colors.black87,
        fontSize: 30,
        fontWeight: FontWeight.bold,
      ),
    ];

    List<String> texts = [];
    List<TextStyle> styles = [];

    // 타이틀 (동네)
    if (title.isNotNullEmptyOrWhitespace) {
      texts.add(title);
      styles.add(textStyles[1]);
      Size textsize = _textSize(
        texts.last,
        textStyles[1],
      );
      if (textWidth < textsize.width) textWidth = textsize.width;
      textHeight += textsize.height;
    }

    // 가격
    prices.forEach((price) {
      texts.add(price);
      Size textsize = _textSize(
        price,
        textStyles[0],
      );
      if (textWidth == null || textWidth < textsize.width)
        textWidth = textsize.width;
      textHeight += textsize.height;
    });

    print(textWidth);

    // 라운드가 지면, 좌우 라운드를 고려해서 박스 크기를 키워줌
    if (rounded == true) {
      textWidth += 30 * 2;
    }

    var size =
        Size((textWidth + imageOffset.dx), (textHeight + imageOffset.dy));

    ui.PictureRecorder recorder = new ui.PictureRecorder();
    Canvas c = new Canvas(recorder);

    // 배경이 지정되어 있으면 그려줌
    if (bgImagePath != null) {
      var imgsize = Size(textWidth, textHeight);
      await drawImage(c, size, bgImagePath, imgsize);
    }

    // 박스를 그려줌
    double boxheight = textHeight;
    Offset textOffset = drawBox(c, Size(size.width, boxheight),
        rounded: true, roundColor: roundColor, borderWidth: 6);

    // 텍스트 스타일을 지정
    prices.forEach((value) {
      Color color = Colors.black;
      if (value.startsWith('아'))
        color = Colors.blueAccent;
      else if (value.startsWith('오'))
        color = Colors.purpleAccent;
      else if (value.startsWith('연'))
        color = Colors.blueGrey;
      else if (value.startsWith('경매')) color = Colors.redAccent;
      styles.add(TextStyle(
          color: color,
          fontSize: textStyles[0].fontSize,
          fontWeight: textStyles[0].fontWeight));
    });

    // 타이틀과 가격을 모두 그림
    _drawMultiLineTexts(c, texts, size.width, boxheight, 1,
        ofs: textOffset, styles: styles, align: TextAlign.center);

    // 최종 비트맵 이미지를 뽑아냄
    ui.Picture p = recorder.endRecording();

    var bitmap = await _drawScaledPictureBitmap(p, size, Util.pixelRatio / 3.0);
    _bitmapMap[bitmapKey] = bitmap;
    return bitmap;
  }

  Future<BitmapDescriptor> _drawScaledPictureBitmap(
      ui.Picture p, Size targetSize, double scale) async {
    ByteData pngBytes = await (await p.toImage(
            targetSize.width.toInt(), targetSize.height.toInt()))
        .toByteData(format: ui.ImageByteFormat.png);

    Uint8List data = Uint8List.view(pngBytes.buffer);

    if (scale != 1) {
      targetSize *= scale;
      var codec = await ui.instantiateImageCodec(data,
          targetHeight: targetSize.height.toInt(),
          targetWidth: targetSize.width.toInt());
      var frameInfo = await codec.getNextFrame();
      ui.Image targetUiImage = frameInfo.image;

      ByteData targetByteData =
          await targetUiImage.toByteData(format: ui.ImageByteFormat.png);
      data = targetByteData.buffer.asUint8List();
    }

    return BitmapDescriptor.fromBytes(data);
  }

  Future<BitmapDescriptor> createMoneyRangeBitmap(String from, String to,
      {String bgImagePath}) async {
    double pinScale = (Util.pixelRatio / 3.0);
    var size = Size(160 * pinScale, 160 * pinScale);
    var imgsize = Size(140 * pinScale, 140 * pinScale);

    ui.PictureRecorder recorder = new ui.PictureRecorder();
    Canvas c = new Canvas(recorder);

    if (bgImagePath != null) {
      ui.Image _iconImage = await loadUiImage(bgImagePath);
      var srcrc = Rect.fromLTRB(
          0, 0, _iconImage.width.toDouble(), _iconImage.height.toDouble());
      var dstrc = Rect.fromLTRB((size.width - imgsize.width) / 2,
          size.height - imgsize.height, imgsize.width, imgsize.height);
      c.drawImageRect(_iconImage, srcrc, dstrc, new Paint());
    }

    int lines = (to.length > 0) ? 2 : 1;
    double boxheight = (lines == 1 ? 70 : 90) * pinScale;
    // box
    c.drawRect(
        Rect.fromLTRB(0, 0, size.width + 10 * pinScale, boxheight),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.round);
    // box shadow
    c.drawRect(
        Rect.fromLTRB(0, 0, size.width + 10 * pinScale, boxheight),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    _drawMoneyRangeText(c, to.length > 0 ? [from, to] : [from], size.width,
        boxheight, pinScale);

    ui.Picture p = recorder.endRecording();
    ByteData pngBytes =
        await (await p.toImage(size.width.toInt(), size.height.toInt()))
            .toByteData(format: ui.ImageByteFormat.png);

    Uint8List data = Uint8List.view(pngBytes.buffer);
    return BitmapDescriptor.fromBytes(data);
  }

  Future<BitmapDescriptor> createCircleTextBitmap(String text,
      {Color bgcolor = Colors.orange,
      Color textcolor = Colors.black,
      double diameterRatio = 1.0}) async {
    String bitmapKey =
        "circle.${bgcolor.value}.${textcolor.value}.$diameterRatio.$text";
    if (_bitmapMap.containsKey(bitmapKey)) {
      return _bitmapMap[bitmapKey];
    }

    double pinScale = (Util.pixelRatio / 3.0) * 1.3;
    var size =
        Size(120 * pinScale * diameterRatio, 120 * pinScale * diameterRatio);

    ui.PictureRecorder recorder = new ui.PictureRecorder();
    Canvas c = new Canvas(recorder);

    List<double> scales = [0, 10, 28];
    List<Color> colors = [bgcolor, Color(0x50ffffff), bgcolor];
    for (int i = 0; i < 3; i++) {
      final Paint paint = Paint()..color = colors[i];
      double diameter = size.width - scales[i];
      Radius radius = Radius.circular(diameter / 2);
      c.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH((size.width - diameter) / 2,
                (size.width - diameter) / 2, diameter, diameter),
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: radius,
          ),
          paint);
    }

    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
          fontSize: 55 * pinScale * math.min(diameterRatio, 1.1),
          color: textcolor),
    );

    painter.layout();
    painter.paint(
        c,
        Offset((size.width * 0.5) - painter.width * 0.5,
            (size.height * 0.5) - painter.height * 0.5));

    ui.Picture p = recorder.endRecording();
    ByteData pngBytes =
        await (await p.toImage(size.width.toInt(), size.height.toInt()))
            .toByteData(format: ui.ImageByteFormat.png);

    Uint8List data = Uint8List.view(pngBytes.buffer);
    BitmapDescriptor bitmap = BitmapDescriptor.fromBytes(data);

    _bitmapMap[bitmapKey] = bitmap;
    return bitmap;
  }
}
*/
