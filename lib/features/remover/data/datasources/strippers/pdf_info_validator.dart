import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_xmp_packet_parser.dart';

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
/// The expected bytes are derived from [findPdfInfoValueMutations], the same
/// trailer-scoped Info plan (including resolved indirect string objects) the
/// scrubber applies, so any byte outside that plan must be unchanged.
/// Because it re-runs that plan rather than deriving the Info ranges
/// independently, it is not an independent oracle: a planning bug would
/// pass here and is guarded only by the locator and validator unit tests.
///
/// This intentionally does not validate PDF structure, xrefs, streams,
/// rendering, signatures, or any metadata surface outside the supported Info
/// key byte patterns. Set [xmpPacketsBlanked] when the scrubber also blanked
/// literal XMP packet content so those bytes are expected to be spaces; the
/// XMP mutation itself is verified by `validateGeneratedPdfXmpMutation`.
void validateGeneratedPdfInfoMutation(
  Uint8List input,
  Uint8List output, {
  Set<String>? selectedKeys,
  bool xmpPacketsBlanked = false,
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
  final expected = Uint8List.fromList(input);
  applyPdfInfoValueMutations(
    expected,
    findPdfInfoValueMutations(inputText, keys),
  );
  if (xmpPacketsBlanked) {
    for (final range in findPdfXmpPacketRanges(inputText)) {
      for (var index = range.start; index < range.end; index++) {
        expected[index] = 0x20;
      }
    }
  }
  for (var index = 0; index < output.length; index++) {
    if (output[index] != expected[index]) {
      throw const FormatException('Generated PDF mutation is invalid');
    }
  }
}

bool _hasPdfSignature(Uint8List bytes) =>
    bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
