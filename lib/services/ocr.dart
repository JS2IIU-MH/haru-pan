import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// 画像ファイルから数字列を抽出して int のリストで返す。
  static Future<List<int>> recognizeImageFromFile(File file) async {
    final inputImage = InputImage.fromFilePath(file.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);

    try {
      final result = await textRecognizer.processImage(inputImage);
      final text = result.text;
      final regex = RegExp(r"\d+");
      final matches = regex.allMatches(text);
      final values = matches.map((m) => int.tryParse(m.group(0) ?? '') ?? 0).toList();
      return values;
    } finally {
      textRecognizer.close();
    }
  }
}
