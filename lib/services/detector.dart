import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:image/image.dart' as img;
// path_provider は Flutter 専用のため使用しない（Dart 実行向けに systemTemp を使用）

class Detector {
  // Tunable parameters for red detection and filtering
  // Hue is in degrees [0,360).
  static const double hueLowA = 0.0;
  static const double hueHighA = 15.0;
  static const double hueLowB = 345.0;
  static const double hueHighB = 360.0;
  static const double satThreshold = 0.35; // increase to reduce false positives
  static const double valThreshold = 0.20; // increase to avoid very dark reds

  // fallback RGB rule
  static const int minRedValue = 170;
  static const int minRedDiff = 50;

  // minimum region size: either absolute pixels or fraction of image
  static const int minRegionAbsolute = 800;
  static const double minRegionFactor = 0.001; // w*h*factor

  // padding ratio for cropping around detected bbox
  static const double padRatio = 0.18;

  /// 画像ファイルから赤い丸の領域を抽出して、領域イメージの File リストを返す。
  /// 簡易アルゴリズム:
  ///  - image パッケージで読み込み
  ///  - 各ピクセルを HSV に変換して赤色閾値で二値マスク作成
  ///  - 連結成分解析で領域のバウンディングボックスを取得
  ///  - 面積閾値で小さなノイズを除去し、領域を切り出して一時ファイルとして保存して返す
  static Future<List<File>> extractRedRegions(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return [];

    final w = image.width;
    final h = image.height;

    // binary mask
    final mask = List.generate(h, (_) => List<bool>.filled(w, false));

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        int r, g, b;
        // handle different Pixel representations across image package versions
        try {
          // when Pixel is encoded as int
          final pi = p as int;
          r = (pi >> 16) & 0xFF;
          g = (pi >> 8) & 0xFF;
          b = pi & 0xFF;
        } catch (_) {
          try {
            // when Pixel is an object with r,g,b fields
            final dyn = p as dynamic;
            r = dyn.r as int;
            g = dyn.g as int;
            b = dyn.b as int;
          } catch (e) {
            // fallback
            r = 0;
            g = 0;
            b = 0;
          }
        }
        final hsv = _rgbToHsv(r, g, b);
        final hue = hsv[0];
        final sat = hsv[1];
        final val = hsv[2];

        // 赤色の閾値: hue が 350~360 or 0~15 程度、sat と val の閾値も付与
        final inHueRange = (hue >= hueLowA && hue <= hueHighA) || (hue >= hueLowB && hue < hueHighB);
        final inSatVal = (sat > satThreshold && val > valThreshold);
        final fallbackRgb = (r > minRedValue && r > g + minRedDiff && r > b + minRedDiff);
        final isRed = (inHueRange && inSatVal) || fallbackRgb;
        mask[y][x] = isRed;
      }
    }

    // connected components (4-neighbor)
    final visited = List.generate(h, (_) => List<bool>.filled(w, false));
    final regions = <Map<String, int>>[]; // {minX,maxX,minY,maxY,count}

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!mask[y][x] || visited[y][x]) continue;
        // bfs
        final q = <Point<int>>[Point(x, y)];
        visited[y][x] = true;
        var idx = 0;
        var minX = x, maxX = x, minY = y, maxY = y;
        while (idx < q.length) {
          final p = q[idx++];
          final px = p.x, py = p.y;
          minX = min(minX, px);
          maxX = max(maxX, px);
          minY = min(minY, py);
          maxY = max(maxY, py);

          final neighbors = [Point(px - 1, py), Point(px + 1, py), Point(px, py - 1), Point(px, py + 1)];
          for (final n in neighbors) {
            final nx = n.x, ny = n.y;
            if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
            if (!visited[ny][nx] && mask[ny][nx]) {
              visited[ny][nx] = true;
              q.add(Point(nx, ny));
            }
          }
        }

        regions.add({'minX': minX, 'maxX': maxX, 'minY': minY, 'maxY': maxY, 'count': q.length});
      }
    }

    // filter regions by area
    final minRegionSize = max(minRegionAbsolute, (w * h * minRegionFactor).round());
    final filtered = regions.where((r) => r['count']! >= minRegionSize).toList();

    final tmpDir = await Directory.systemTemp.createTemp('harupan_regions_');
    final outFiles = <File>[];
    var idx = 0;
    for (final r in filtered) {
      final minX = r['minX']!;
      final maxX = r['maxX']!;
      final minY = r['minY']!;
      final maxY = r['maxY']!;
      final wbox = maxX - minX + 1;
      final hbox = maxY - minY + 1;

      // padding
      final padX = (wbox * padRatio).round();
      final padY = (hbox * padRatio).round();
      final cx = max(0, minX - padX);
      final cy = max(0, minY - padY);
      final cw = min(w - cx, wbox + padX * 2);
      final ch = min(h - cy, hbox + padY * 2);

      final crop = img.copyCrop(image, x: cx, y: cy, width: cw, height: ch);
      final outPath = '${tmpDir.path}/harupan_region_${idx++}.jpg';
      final outFile = File(outPath);
      await outFile.writeAsBytes(img.encodeJpg(crop, quality: 90));
      outFiles.add(outFile);
    }

    // if no region detected, fallback to original image
    if (outFiles.isEmpty) return [imageFile];
    return outFiles;
  }

  static List<double> _rgbToHsv(int r, int g, int b) {
    final rf = r / 255.0;
    final gf = g / 255.0;
    final bf = b / 255.0;
    final maxv = max(rf, max(gf, bf));
    final minv = min(rf, min(gf, bf));
    final d = maxv - minv;
    double h = 0.0;
    if (d == 0) h = 0.0;
    else if (maxv == rf) h = 60 * (((gf - bf) / d) % 6);
    else if (maxv == gf) h = 60 * (((bf - rf) / d) + 2);
    else if (maxv == bf) h = 60 * (((rf - gf) / d) + 4);
    if (h < 0) h += 360;
    final s = maxv == 0 ? 0.0 : d / maxv;
    final v = maxv;
    return [h, s, v];
  }
}
