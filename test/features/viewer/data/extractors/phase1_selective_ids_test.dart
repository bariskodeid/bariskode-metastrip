import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/pdf_extractor.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/png_text_extractor.dart';

void main() {
  test('PNG extractor assigns an ID from the exact keyword', () async {
    const keyword = 'Creation Time / v2';
    final bytes = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('tEXt', '$keyword\u0000today'.codeUnits),
      ..._pngChunk('IEND', const []),
    ]);

    final fields = await extractPngText(bytes);

    expect(fields.single.id, MetadataFieldId.pngText(keyword));
    expect(fields.single.id?.pngKeyword, keyword);
  });

  test('PDF assigns IDs only to DocInfo fields, not XMP', () async {
    final fields = await extractPdf(
      Uint8List.fromList(
        '%PDF-1.4\n'
                '1 0 obj << /Info 2 0 R >> endobj\n'
                '2 0 obj << /Author (Ada) /Title (Notes) >> endobj\n'
                '<?xpacket begin="x"?>data<?xpacket end="w"?>'
            .codeUnits,
      ),
    );

    expect(
      fields.firstWhere((field) => field.label == 'Author').id,
      MetadataFieldId.pdfInfoAuthor,
    );
    expect(
      fields.firstWhere((field) => field.label == 'Title').id,
      MetadataFieldId.pdfInfoTitle,
    );
    expect(
        fields.firstWhere((field) => field.label == 'XMP Packet').id, isNull);
  });

  test('malformed PNG keyword remains visible but is not selectable', () async {
    final bytes = Uint8List.fromList([
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      ..._pngChunk('tEXt', ' bad\u0000value'.codeUnits),
      ..._pngChunk('tEXt', 'Author\u0000Ada'.codeUnits),
      ..._pngChunk('IEND', const []),
    ]);

    final fields = await extractPngText(bytes);

    expect(fields, hasLength(2));
    expect(fields.first.id, isNull);
    expect(fields.last.id, MetadataFieldId.pngText('Author'));
  });
}

List<int> _pngChunk(String type, List<int> data) {
  final length = ByteData(4)..setUint32(0, data.length);
  final contents = <int>[...type.codeUnits, ...data];
  final crc = ByteData(4)..setUint32(0, _crc32(contents));
  return [
    ...length.buffer.asUint8List(),
    ...contents,
    ...crc.buffer.asUint8List(),
  ];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB88320;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
