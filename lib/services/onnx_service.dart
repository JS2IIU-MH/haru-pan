import 'dart:typed_data';
import 'package:flutter/services.dart';

class OnnxService {
  static const MethodChannel _ch = MethodChannel('harupan/onnx');

  /// Load model packaged in assets (asset path relative to Flutter assets)
  static Future<bool> loadModel(String assetPath) async {
    final res = await _ch.invokeMethod('loadModel', {'assetPath': assetPath});
    return res == true;
  }

  /// Run inference on an image bytes (JPEG/PNG). Returns flattened float outputs.
  static Future<List<double>> run(Uint8List imageBytes, {int imgsz = 640}) async {
    final res = await _ch.invokeMethod('run', {'imageBytes': imageBytes, 'imgsz': imgsz});
    // result comes back as List<dynamic> of numbers
    return (res as List).map((e) => (e as num).toDouble()).toList();
  }
}
