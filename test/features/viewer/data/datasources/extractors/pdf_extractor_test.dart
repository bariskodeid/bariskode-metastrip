import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/viewer/data/datasources/extractors/pdf_extractor.dart';

void main() {
  group('extractPdf', () {
    test('extracts Info dictionary fields via an indirect reference', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog >>',
        'endobj',
        '7 0 obj',
        '<< /Title (Hello World) /Author (Jane Doe) '
            '/CreationDate (D:20240101120000) >>',
        'endobj',
      ], info: '7 0 R');

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

    test('extracts an Info dictionary declared inline in the trailer',
        () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog >>',
        'endobj',
      ], info: '<< /Producer (Acme PDF) /Trapped true >>');

      final fields = await extractPdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Producer']?.value, 'Acme PDF');
      expect(byLabel['Trapped']?.value, 'true');
    });

    test('decodes a hex string Info value', () async {
      final bytes = _pdfBytes([
        '7 0 obj',
        '<< /Subject <4869205468657265> >>',
        'endobj',
      ], info: '7 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Subject').value,
        'Hi There',
      );
    });

    test('decodes escaped parentheses in literal strings', () async {
      final bytes = _pdfBytes([
        '7 0 obj',
        '<< /Title (Title \\(test\\)) >>',
        'endobj',
      ], info: '7 0 R');

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

  group('extractPdf Info location', () {
    test('reads Info referenced from classic trailer', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog /Pages 2 0 R >>',
        'endobj',
        '5 0 obj',
        '<< /Title (Trailer Title) /Author (Ann) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Title']?.value, 'Trailer Title');
      expect(byLabel['Title']?.id, MetadataFieldId.pdfInfoTitle);
      expect(byLabel['Author']?.value, 'Ann');
      expect(byLabel['Author']?.id, MetadataFieldId.pdfInfoAuthor);
    });

    test('reads Info object beyond the 64th object', () async {
      final bytes = _pdfBytes([
        for (var number = 1; number <= 70; number++) ...[
          '$number 0 obj',
          '<< /Type /Filler /Index $number >>',
          'endobj',
        ],
        '71 0 obj',
        '<< /Title (Late Info) >>',
        'endobj',
      ], info: '71 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Title').value,
        'Late Info',
      );
    });

    test('shows the latest revision value of each key', () async {
      // An incremental update redefines object 5 and adds a later trailer.
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title (Old Title) /Author (Old Author) /Subject (Kept) >>',
        'endobj',
        'trailer',
        '<< /Size 6 /Info 5 0 R >>',
        '5 0 obj',
        '<< /Title (New Title) /Author (New Author) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Title').value,
        'New Title',
      );
      expect(
        fields.singleWhere((field) => field.label == 'Author').value,
        'New Author',
      );
      expect(
        fields.singleWhere((field) => field.label == 'Subject').value,
        'Kept',
      );
    });

    test('ignores /Info keys outside trailers', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog /Info 7 0 R >>',
        'endobj',
        '7 0 obj',
        '<< /Title (Not Document Info) >>',
        'endobj',
      ]);

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, 'No PDF metadata found');
    });

    test('indirect Info value is resolved', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title 12 0 R /Author (Ann) >>',
        'endobj',
        '12 0 obj',
        '(Resolved Title)',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);
      final title = fields.singleWhere((field) => field.label == 'Title');

      expect(title.value, 'Resolved Title');
      expect(title.id, MetadataFieldId.pdfInfoTitle);
    });

    test('truncated literal yields status field, no throw', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title (unterminated >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(fields, hasLength(1));
      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
      expect(fields.single.id, isNull);
    });

    test('unresolvable Info reference yields status field', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog >>',
        'endobj',
      ], info: '9 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('non-string indirect Info value yields status field', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title 12 0 R >>',
        'endobj',
        '12 0 obj',
        '<< /Not (a string) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('unresolvable indirect Info value yields status field', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title 12 0 R >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('mismatched brackets in inline Info yield status field', () async {
      // The locator's nested-value skipper shares one depth counter between
      // `[` and `<<`, so this inline Info gets a bogus range end.
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Catalog >>',
        'endobj',
      ], info: '<< /Title (x) /Odd [ >> ] >>');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('endobj inside an Info string yields status field', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title (ends endobj early) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('object header inside stream data yields status field', () async {
      // The locator cannot tell stream data from objects, so the fake
      // `5 0 obj` in the stream is taken as a definition of the Info object.
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Length 12 >>',
        'stream',
        '5 0 obj fake',
        'endstream',
        'endobj',
        '5 0 obj',
        '<< /Title (Real) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.single.label, 'Status');
      expect(fields.single.value, _infoStatus);
    });

    test('Info failure keeps the XMP packet visible', () async {
      final bytes = _pdfBytes([
        '1 0 obj',
        '<< /Type /Metadata /Subtype /XML /Length 60 >>',
        'stream',
        '<?xpacket begin=""?><x:xmpmeta/><?xpacket end="w"?>',
        'endstream',
        'endobj',
      ], info: '9 0 R');

      final fields = await extractPdf(bytes);

      expect(fields.map((field) => field.label), ['Status', 'XMP Packet']);
      expect(fields.first.value, _infoStatus);
    });
  });

  group('extractPdf string decoding', () {
    test('decodes UTF-16BE BOM title', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        r'<< /Title <FEFF00410042> /Subject (\376\377\000A\000B) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);
      final byLabel = {for (final field in fields) field.label: field};

      expect(byLabel['Title']?.value, 'AB');
      expect(byLabel['Subject']?.value, 'AB');
    });

    test('decodes octal escape', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        r'<< /Author (J\101ne) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Author').value,
        'JAne',
      );
    });

    test('keeps balanced nested parentheses', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title (a (b) c) >>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Title').value,
        'a (b) c',
      );
    });

    test('reads hex value adjacent to >>', () async {
      final bytes = _pdfBytes([
        '5 0 obj',
        '<< /Title <414243>>>',
        'endobj',
      ], info: '5 0 R');

      final fields = await extractPdf(bytes);

      expect(
        fields.singleWhere((field) => field.label == 'Title').value,
        'ABC',
      );
    });
  });
}

/// Status value reported when the Info dictionary cannot be read.
const _infoStatus = 'Unable to parse PDF Info dictionary';

/// Builds a minimal, valid-looking PDF byte buffer from [objects].
///
/// Each entry in [objects] is written verbatim between the `%PDF-` header and
/// the trailer so tests can describe any object layout they need.
/// When [info] is given it is written as the trailer's `/Info` value, either
/// an indirect reference such as `7 0 R` or an inline dictionary.
Uint8List _pdfBytes(List<String> objects, {String? info}) {
  final content = StringBuffer()..writeln('%PDF-1.4');
  for (final object in objects) {
    content.writeln(object);
  }
  final infoEntry = info == null ? '' : ' /Info $info';
  content.writeln('trailer');
  content.writeln('<< /Root 1 0 R /Size ${objects.length + 1}$infoEntry >>');
  content.writeln('%%EOF');
  return Uint8List.fromList(latin1.encode(content.toString()));
}