import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/detector.dart';
import '../services/ocr.dart';

/// 開発用: assets/test_images 配下の画像を使って検出→OCRを実行し、結果を CSV に出力するページ。
/// - 使い方:
///   1. `assets/test_images/` に評価用画像を置く
///   2. (任意) `assets/test_images/ground_truth.csv` を用意（filename,expected_sum の形式）
///   3. `pubspec.yaml` に assets を登録してアプリをビルド

class EvaluatorPage extends StatefulWidget {
  const EvaluatorPage({Key? key}) : super(key: key);

  @override
  State<EvaluatorPage> createState() => _EvaluatorPageState();
}

class _EvaluatorPageState extends State<EvaluatorPage> {
  String _log = '';
  bool _running = false;

  void _appendLog(String s) {
    setState(() {
      _log = '$_log\n$s';
    });
  }

  Future<void> _runEvaluation() async {
    if (_running) return;
    setState(() => _running = true);
    _log = '';

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestContent);
      final assetPaths = manifest.keys.where((k) => k.startsWith('assets/test_images/')).toList();

      // ground truth optional
      Map<String, String> ground = {};
      try {
        final gt = await rootBundle.loadString('assets/test_images/ground_truth.csv');
        for (final line in LineSplitter.split(gt)) {
          final parts = line.split(',');
          if (parts.length >= 2) ground[parts[0].trim()] = parts[1].trim();
        }
      } catch (_) {}

      final results = <List<String>>[];
      results.add(['filename', 'recognized_values', 'recognized_sum', 'expected_sum', 'match']);

      for (final asset in assetPaths) {
        _appendLog('処理中: $asset');
        final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final tmpFile = File('${tempDir.path}/${asset.split('/').last}');
        await tmpFile.writeAsBytes(bytes);

        final regions = await Detector.extractRedRegions(tmpFile);
        final recognizedValues = <int>[];
        for (final region in regions) {
          final vals = await OcrService.recognizeImageFromFile(region);
          recognizedValues.addAll(vals);
        }
        final sum = recognizedValues.fold<int>(0, (a, b) => a + b);
        final expected = ground[asset.split('/').last];
        final match = expected != null ? (int.tryParse(expected) == sum).toString() : '';

        results.add([asset.split('/').last, recognizedValues.join(';'), sum.toString(), expected ?? '', match]);
        _appendLog('結果: ${asset.split('/').last} -> $recognizedValues (sum=$sum)');
      }

      // CSV 出力
      final docs = await getApplicationDocumentsDirectory();
      final out = File('${docs.path}/eval_results.csv');
      final sink = out.openWrite();
      for (final row in results) {
        sink.writeln(row.map((e) => '"${e.replaceAll('"', '""')}"').join(','));
      }
      await sink.flush();
      await sink.close();
      _appendLog('CSVを出力しました: ${out.path}');
    } catch (e, st) {
      _appendLog('エラー: $e');
      if (kDebugMode) _appendLog(st.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluator')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _running ? null : _runEvaluation,
              child: Text(_running ? '実行中...' : '評価を実行'),
            ),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text(_log))),
          ],
        ),
      ),
    );
  }
}
