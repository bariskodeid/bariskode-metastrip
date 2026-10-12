import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/metadata_remover_datasource.dart';

void main() {
  group('PDF XMP packet removal', () {
    late Directory directory;
    late File input;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('metastrip_pdf_xmp_');
      input = File('${directory.path}${Platform.pathSeparator}doc.pdf');
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('blanks packet content while preserving markers and length', () async {
      const payload = '<x:xmpmeta><dc:creator>Ada</dc:creator></x:xmpmeta>';
      const source = '%PDF-1.4\n/Producer (Acme)\n'
          '$_begin$payload$_end\nTRAILING\n%%EOF';
      await input.writeAsString(source);

      final output = await MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: directory.path,
      );
      final text = await output.readAsString();

      expect(text.length, source.length);
      expect(text, contains(_begin));
      expect(text, contains(_end));
      expect(text, contains('$_begin${' ' * payload.length}$_end'));
      expect(text, isNot(contains('Ada')));
      expect(text, isNot(contains('dc:creator')));
      expect(text, contains('/Producer (    )'));
      expect(text, contains('TRAILING'));
    });

    test('blanks every packet in a multi-packet payload', () async {
      const source = '%PDF-1.4\n$_begin AAA $_end mid $_begin BBB $_end\n%%EOF';
      await input.writeAsString(source);

      final output = await MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: directory.path,
      );
      final text = await output.readAsString();

      expect(text.length, source.length);
      expect(text, isNot(contains('AAA')));
      expect(text, isNot(contains('BBB')));
      expect(text, contains(' mid '));
    });

    test('fails closed and writes no output on an unbalanced packet', () async {
      await input.writeAsString('%PDF-1.4\n$_begin<x:xmpmeta/>\n%%EOF');

      await expectLater(
        MetadataRemoverDatasource().stripPdfMetadata(
          input.path,
          outputDirectory: directory.path,
        ),
        throwsFormatException,
      );
      expect(
        File('${directory.path}${Platform.pathSeparator}doc_clean.pdf')
            .existsSync(),
        isFalse,
      );
    });

    test('fails closed on an end instruction without a begin', () async {
      await input.writeAsString('%PDF-1.4\n$_end\n%%EOF');

      await expectLater(
        MetadataRemoverDatasource().stripPdfMetadata(
          input.path,
          outputDirectory: directory.path,
        ),
        throwsFormatException,
      );
      expect(directory.listSync().length, 1);
    });

    test('leaves packets untouched in selective Info removal', () async {
      const payload = '<x:xmpmeta>Keep</x:xmpmeta>';
      await input.writeAsString(
        '%PDF-1.4\n/Title (Secret)/Author (Ada)\n$_begin$payload$_end\n%%EOF',
      );

      final output = await MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: directory.path,
        selectiveLabels: {'Title'},
      );
      final text = await output.readAsString();

      expect(text, contains('/Title (      )'));
      expect(text, contains('/Author (Ada)'));
      expect(text, contains(payload));
    });

    test('keeps Info-only behavior for a PDF without a packet', () async {
      await input.writeAsString(
        '%PDF-1.4\n1 0 obj<</Title (Secret)/Author (Alice)>>endobj\n%%EOF',
      );

      final output = await MetadataRemoverDatasource().stripPdfMetadata(
        input.path,
        outputDirectory: directory.path,
      );
      final text = await output.readAsString();

      expect(text, contains('/Title (      )'));
      expect(text, contains('/Author (     )'));
      expect(text, isNot(contains('Secret')));
      expect(text, isNot(contains('Alice')));
    });
  });
}

const _begin = '<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>';
const _end = '<?xpacket end="w"?>';
