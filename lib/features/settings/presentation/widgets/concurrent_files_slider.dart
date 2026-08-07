import 'package:flutter/material.dart';

/// Slider for max concurrent file processing (1-8).
class ConcurrentFilesSlider extends StatefulWidget {
  const ConcurrentFilesSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<ConcurrentFilesSlider> createState() => _ConcurrentFilesSliderState();
}

class _ConcurrentFilesSliderState extends State<ConcurrentFilesSlider> {
  late int _draftValue = widget.value;

  @override
  void didUpdateWidget(ConcurrentFilesSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _draftValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.speed_outlined),
      title: const Text('Concurrent Files'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$_draftValue files'),
          Slider(
            value: _draftValue.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$_draftValue files',
            onChanged: (value) => setState(() => _draftValue = value.round()),
            onChangeEnd: (value) {
              final persistedValue = value.round();
              if (persistedValue != widget.value) {
                widget.onChanged(persistedValue);
              }
            },
          ),
        ],
      ),
    );
  }
}
