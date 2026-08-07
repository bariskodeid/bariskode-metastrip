import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/pdf_extractor.dart';

void main() {
  group('extractPdf', () {
    test('extracts Info dictionary fields via an indirect reference', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Info 7 0 R >>',
        'endobj',
        '7 0 obj',
        '<< /Title (Hello World) /Author (Jane Doe) '
            '/CreationDate (D:20240101120000) >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      final title = byLabel['Title'];
      expect(title, isNotNull);
      expect(title!.section, 'PDF Document');
      expect(title.value, 'Hello World');
      expect(title.isPrivacySensitive, isFalse);

      final author = byLabel['Author'];
      expect(author?.value, 'Jane Doe');
      expect(author?.isPrivacySensitive, isTrue);

      expect(byLabel['CreationDate']?.value, 'D:20240101120000');
    });

    test('extracts an Info dictionary declared directly in an object',
        () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog /Info '
            '<< /Producer (Acme PDF) /Trapped true >> >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Producer']?.value, 'Acme PDF');
      expect(byLabel['Trapped']?.value, 'true');
    });

    test('decodes a hex string Info value', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Info 7 0 R >>',
        'endobj',
        '7 0 obj',
        '<< /Subject <4869205468657265> >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Subject').value,
        'Hi There',
      );
    });

    test('decodes escaped parentheses in literal strings', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Info 7 0 R >>',
        'endobj',
        '7 0 obj',
        '<< /Title (Title \\(test\\)) >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Title').value,
        'Title (test)',
      );
    });

    test('reports an XMP Packet field when an xpacket is present', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Metadata /Subtype /XML /Length 120 >>',
        'stream',
        '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>',
        '<x:xmpmeta xmlns:x="adobe:ns:meta/" />',
        '<?xpacket end="w"?>',
        'endstream',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);
      final xmp = fields.singleWhere((field) => field.label == 'XMP Packet');

      expect(xmp.section, 'PDF Document');
      expect(xmp.value, contains('<?xpacket'));
    });

    test('returns a status field when no PDF metadata is found', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog /Pages 2 0 R >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'PDF Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No PDF metadata found');
    });

    test('returns a status field for bytes that are not a PDF', () async {
      final bytes = Uint8List.fromList(utf8.encode('definitely not a pdf'));

      final fields = await extractPdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.section, 'PDF Document');
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'Not a valid PDF');
    });

    test('handles a PDF with many object markers that never reach endobj',
        () async {
      // A hostile PDF can repeat `N 0 obj` headers without any `endobj`
      // terminator; the scan must stay bounded instead of hanging.
      final builder = StringBuffer()..writeln('%PDF-1.4');
      for (var i = 0; i < 1000; i++) {
        builder.writeln('${i + 1} 0 obj');
        builder.writeln('<< /Title (Marker $i) >>');
      }
      builder.writeln('%%EOF');
      final bytes = Uint8List.fromList(latin1.encode(builder.toString()));

      final fields = await extractPdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No PDF metadata found');
    });
  });
}

/// Builds a minimal, valid-looking PDF byte buffer from [objects].
///
/// Each entry in [objects] is written verbatim between the `%PDF-` header and
/// the trailer so tests can describe any object layout they need.
Uint8List _pdfBytes(List<String> objects) {
  final content = StringBuffer()..writeln('%PDF-1.4');
  for (final object in objects) {
    content.writeln(object);
  }
  content.writeln('trailer');
  content.writeln('<< /Root 1 0 R /Size ${objects.length + 1} >>');
  content.writeln('%%EOF');
  return Uint8List.fromList(latin1.encode(content.toString()));
}