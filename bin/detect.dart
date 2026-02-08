import 'dart:io';
import 'package:harupan/services/detector.dart';

/// 実行方法:
/// ```
/// flutter pub get
/// dart run bin/detect.dart
/// ```
/// 出力:
/// - assets/test_images/detection_results.csv
/// - 一時ディレクトリに切り出し画像（各入力ごとにファイル名表示）

Future<void> main() async {
  final dir = Directory('assets/test_images');
  if (!await dir.exists()) {
    print('assets/test_images が見つかりません');
    return;
  }

  final files = dir.listSync().whereType<File>().where((f) {
    final lower = f.path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }).toList();

  final csvLines = <String>['filename,region_count,region_files'];

  for (final f in files) {
    print('処理: ${f.path}');
    try {
      final regions = await Detector.extractRedRegions(f);
      final regionNames = regions.map((r) => r.path.split(Platform.pathSeparator).last).join(';');
      csvLines.add('${f.path.split(Platform.pathSeparator).last},${regions.length},"$regionNames"');
      print('  検出領域: ${regions.length}');
      for (final r in regions) {
        print('    -> ${r.path}');
      }
    } catch (e) {
      print('  エラー: $e');
      csvLines.add('${f.path.split(Platform.pathSeparator).last},ERROR,');
    }
  }

  final out = File('assets/test_images/detection_results.csv');
  await out.writeAsString(csvLines.join('\n'));
  print('結果を出力しました: ${out.path}');
}
