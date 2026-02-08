import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/detector.dart';
import '../services/ocr.dart';
import 'result_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final ok = await _ensurePermissions();
    if (!ok) return;
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras!.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      // カメラ初期化失敗時はエラー表示は後で追加
    }
  }

  Future<bool> _ensurePermissions() async {
    // Request camera permission
    final camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) {
      final res = await Permission.camera.request();
      if (!res.isGranted) {
        if (mounted) {
          await showDialog<void>(context: context, builder: (context) {
            return AlertDialog(
              title: const Text('権限が必要です'),
              content: const Text('カメラ権限が必要です。設定から許可してください。'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('閉じる')),
              ],
            );
          });
        }
        return false;
      }
    }

    // Request storage/gallery permission for image picking
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      final res = await Permission.storage.request();
      // On Android 13+, READ_MEDIA_IMAGES may be needed; request if available
      if (!res.isGranted) {
        final mediaRes = await Permission.photos.request();
        if (!mediaRes.isGranted) {
          // not fatal; gallery features may be limited
        }
      }
    }

    return true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;
    final ok = await _ensurePermissions();
    if (!ok) return;
    setState(() => _isProcessing = true);

    try {
      final XFile file = await _controller!.takePicture();
      final File imageFile = File(file.path);

      // 1) 色ベースの領域抽出（仮）
      final regions = await Detector.extractRedRegions(imageFile);

      // 2) OCR 実行（領域ごと）
      final List<int> numbers = [];
      for (final region in regions) {
        final vals = await OcrService.recognizeImageFromFile(region);
        numbers.addAll(vals);
      }

      final total = numbers.fold<int>(0, (a, b) => a + b);

      // 結果画面へ遷移
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) {
        return ResultPage(numbers: numbers, regionFiles: regions);
      }));
    } catch (e) {
      // エラー処理は後で拡充
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Harupan - スキャン')),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CameraPreview(_controller!),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        onPressed: _isProcessing ? null : _onCapturePressed,
                        child: _isProcessing
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Icon(Icons.camera_alt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
