import 'dart:io';

import 'package:flutter/material.dart';

class ResultPage extends StatefulWidget {
  final List<int> numbers;
  final List<File> regionFiles;

  const ResultPage({Key? key, required this.numbers, required this.regionFiles}) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late List<int> _values;

  @override
  void initState() {
    super.initState();
    _values = List<int>.from(widget.numbers);
  }

  void _editValue(int index) async {
    final controller = TextEditingController(text: _values.length > index ? _values[index].toString() : '0');
    final result = await showDialog<int?>(context: context, builder: (context) {
      return AlertDialog(
        title: const Text('値を編集'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '数値を入力'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('キャンセル')),
          TextButton(onPressed: () {
            final v = int.tryParse(controller.text) ?? 0;
            Navigator.of(context).pop(v);
          }, child: const Text('保存')),
        ],
      );
    });

    if (result != null) {
      setState(() {
        if (_values.length > index) _values[index] = result;
      });
    }
  }

  int get _total => _values.fold<int>(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final count = _values.length;
    return Scaffold(
      appBar: AppBar(title: const Text('検出結果')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: count,
              itemBuilder: (context, i) {
                final val = _values[i];
                final file = i < widget.regionFiles.length ? widget.regionFiles[i] : null;
                return ListTile(
                  leading: file != null ? Image.file(file, width: 56, height: 56, fit: BoxFit.cover) : const Icon(Icons.sticky_note_2),
                  title: Text('値: $val'),
                  subtitle: Text('領域 ${i + 1}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editValue(i),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('合計: $_total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_values),
                  child: const Text('完了'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
