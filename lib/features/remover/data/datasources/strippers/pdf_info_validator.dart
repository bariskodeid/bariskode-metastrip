import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';

/// The Info keys covered by the current bounded PDF byte scrubber.
const pdfInfoValidationKeys = <String>[
  'Title',
  'Author',
  'Subject',
  'Keywords',
  'Creator',
  'Producer',
  'CreationDate',
  'ModDate',
  'Trapped',
];

/// Verifies the generated mutation made by the bounded PDF Info scrubber.
///
/// This intentionally does not validate PDF structure, xrefs, streams, XMP,
/// rendering, signatures, or any metadata surface outside the supported Info
/// key byte patterns.
void validateGeneratedPdfInfoMutation(
  Uint8List input,
  Uint8List output, {
  Set<String>? selectedKeys,
}) {
  if (input.length > AppConstants.maxRemoverFileSizeBytes ||
      output.length > AppConstants.maxRemoverFileSizeBytes) {
    throw const FormatException('PDF exceeds bounded validation limit');
  }
  if (!_hasPdfSignature(input) || !_hasPdfSignature(output)) {
    throw const FormatException('Not a valid PDF file');
  }
  if (input.length != output.length) {
    throw const FormatException('Generated PDF size changed');
  }
  final keys = selectedKeys == null
      ? pdfInfoValidationKeys
      : pdfInfoValidationKeys.where(selectedKeys.contains).toList();
  if (selectedKeys != null &&
      (selectedKeys.isEmpty || keys.length != selectedKeys.length)) {
    throw const FormatException('Unsupported selective metadata field');
  }

  final inputText = latin1.decode(input);
  final ranges = <PdfInfoValueRange>[];
  final replacements = <int, int>{};
  final occurrenceBudget = PdfInfoOccurrenceBudget();
  for (final key in keys) {
    var from = 0;
    while (true) {
      final marker = inputText.indexOf('/$key', from);
      if (marker < 0) break;
      occurrenceBudget.record();
      final keyEnd = marker + key.length + 1;
      if (keyEnd < inputText.length &&
          isPdfInfoNameChar(inputText.codeUnitAt(keyEnd))) {
        from = keyEnd + 1;
        continue;
      }
      final range = parsePdfInfoValueRange(inputText, keyEnd);
      if (range == null) {
        throw FormatException('Malformed PDF Info value for $key');
      }
      ranges.add(range);
      replacements.removeWhere(
        (position, _) => position >= range.start && position < range.end,
      );
      if (range.replacementAtStart case final replacement?) {
        replacements[range.start] = replacement;
      }
      from = range.nextSearchOffset;
    }
  }

  ranges.sort((left, right) => left.start.compareTo(right.start));
  final mergedRanges = <PdfInfoValueRange>[];
  for (final range in ranges) {
    if (mergedRanges.isEmpty || range.start > mergedRanges.last.end) {
      mergedRanges.add(range);
      continue;
    }
    final previous = mergedRanges.removeLast();
    mergedRanges.add(
      PdfInfoValueRange(
        previous.start,
        range.end > previous.end ? range.end : previous.end,
        range.nextSearchOffset,
      ),
    );
  }

  var rangeIndex = 0;
  for (var byteIndex = 0; byteIndex < input.length; byteIndex++) {
    while (rangeIndex < mergedRanges.length &&
        byteIndex >= mergedRanges[rangeIndex].end) {
      rangeIndex++;
    }
    final isMutable = rangeIndex < mergedRanges.length &&
        byteIndex >= mergedRanges[rangeIndex].start;
    final expected =
        replacements[byteIndex] ?? (isMutable ? 0x20 : input[byteIndex]);
    if (output[byteIndex] != expected) {
      throw const FormatException('Generated PDF mutation is invalid');
    }
  }
}

bool _hasPdfSignature(Uint8List bytes) =>
    bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
