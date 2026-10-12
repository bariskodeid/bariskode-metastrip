import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/core/constants/app_constants.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_xmp_packet_parser.dart';

/// Verifies the generated mutation made by the bounded PDF XMP scrubber.
///
/// This confirms that every literal XMP packet's content was blanked with
/// spaces, that both `xpacket` instructions survived, and that the output byte
/// length is unchanged. It intentionally does not validate PDF structure,
/// xrefs, streams, rendering, signatures, or XMP hidden inside compressed
/// object streams.
void validateGeneratedPdfXmpMutation(Uint8List input, Uint8List output) {
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

  final ranges = findPdfXmpPacketRanges(latin1.decode(input));
  for (final range in ranges) {
    for (var index = range.start; index < range.end; index++) {
      if (output[index] != 0x20) {
        throw const FormatException('Generated PDF XMP mutation is invalid');
      }
    }
  }

  final outputRanges = findPdfXmpPacketRanges(latin1.decode(output));
  if (outputRanges.length != ranges.length) {
    throw const FormatException('Generated PDF XMP packet markers changed');
  }
  for (var index = 0; index < ranges.length; index++) {
    if (outputRanges[index].start != ranges[index].start ||
        outputRanges[index].end != ranges[index].end) {
      throw const FormatException('Generated PDF XMP packet markers changed');
    }
  }
}

bool _hasPdfSignature(Uint8List bytes) =>
    bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
