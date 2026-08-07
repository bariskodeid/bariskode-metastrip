import 'package:flutter/material.dart';

/// Slider for JPEG output quality (70-100).
class JpegQualitySlider extends StatefulWidget {
  const JpegQualitySlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<JpegQualitySlider> createState() => _JpegQualitySliderState();
}

class _JpegQualitySliderState extends State<JpegQualitySlider> {
  late int _draftValue = widget.value;

  @override
  void didUpdateWidget(JpegQualitySlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _draftValue = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.image_outlined),
      title: const Text('JPEG Quality'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$_draftValue%'),
          Slider(
            value: _draftValue.toDouble(),
            min: 70,
            max: 100,
            divisions: 30,
            label: '$_draftValue%',
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
