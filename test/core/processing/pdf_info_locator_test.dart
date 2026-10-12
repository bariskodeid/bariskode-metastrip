import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/processing/pdf_info_locator.dart';

void main() {
  group('locatePdfInfoDictionaries', () {
    test('locates Info via classic trailer', () {
      const text = '%PDF-1.4\n'
          '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n'
          '5 0 obj\n<< /Title (Secret) /Author (Ada) >>\nendobj\n'
          'xref\n0 1\n0000000000 65535 f \n'
          'trailer\n<< /Size 6 /Root 1 0 R /Info 5 0 R >>\n'
          'startxref\n0\n%%EOF';

      final ranges = locatePdfInfoDictionaries(text);

      expect(ranges, hasLength(1));
      expect(
        _slice(text, ranges.single),
        ' /Title (Secret) /Author (Ada) ',
      );
    });

    test('locates Info via xref stream dictionary', () {
      const text = '%PDF-1.5\n'
          '7 0 obj\n<</Producer (Acme)>>\nendobj\n'
          '9 0 obj\n<< /Info 7 0 R /Root 1 0 R /DecodeParms << /Columns 4 >> '
          '/Type /XRef /W [1 2 1] /Size 10 /Length 4 >>\n'
          'stream\nABCD\nendstream\nendobj\n'
          'startxref\n0\n%%EOF';

      final ranges = locatePdfInfoDictionaries(text);

      expect(ranges, hasLength(1));
      expect(_slice(text, ranges.single), '/Producer (Acme)');
    });

    test('finds every revision of an incrementally updated Info object', () {
      const text = '%PDF-1.4\n'
          '3 0 obj\n<< /Title (Draft) >>\nendobj\n'
          'trailer\n<< /Size 4 /Info 3 0 R >>\n%%EOF\n'
          '3 0 obj\n<< /Title (Final) >>\nendobj\n'
          '4 0 obj\n<< /Author (Bea) >>\nendobj\n'
          'trailer\n<< /Size 5 /Prev 0 /Info 3 0 R >>\n%%EOF\n'
          'trailer\n<< /Size 5 /Prev 0 /Info 4 0 R >>\n%%EOF';

      final ranges = locatePdfInfoDictionaries(text);

      expect(
        ranges.map((range) => _slice(text, range)),
        [' /Title (Draft) ', ' /Title (Final) ', ' /Author (Bea) '],
      );
    });

    test('returns empty when no /Info reference exists', () {
      const text = '%PDF-1.4\n'
          '1 0 obj\n<< /Title (Chapter 1) >>\nendobj\n'
          'trailer\n<< /Size 2 /Root 1 0 R >>\n%%EOF';

      expect(locatePdfInfoDictionaries(text), isEmpty);
    });

    test('ignores /Info outside trailer and xref stream dictionaries', () {
      const text = '%PDF-1.4\n'
          '1 0 obj\n<< /Title (Chapter 1) >>\nendobj\n'
          '2 0 obj\n<< /Info 1 0 R >>\nendobj\n'
          'trailer\n<< /Size 3 >>\n%%EOF';

      expect(locatePdfInfoDictionaries(text), isEmpty);
    });

    test('locates an inline Info dictionary in a trailer', () {
      const text = '%PDF-1.4\ntrailer\n<< /Info << /Title (Inline) >> >>\n';

      final ranges = locatePdfInfoDictionaries(text);

      expect(ranges, hasLength(1));
      expect(_slice(text, ranges.single), ' /Title (Inline) ');
    });

    test('fails closed when an Info reference has no plain-text definition',
        () {
      const text = '%PDF-1.5\ntrailer\n<< /Info 8 0 R >>\n%%EOF';

      expect(() => locatePdfInfoDictionaries(text), throwsFormatException);
    });

    test('fails closed when the Info object is not a dictionary', () {
      const text = '%PDF-1.4\n5 0 obj (Secret) endobj\n'
          'trailer\n<< /Info 5 0 R >>\n%%EOF';

      expect(() => locatePdfInfoDictionaries(text), throwsFormatException);
    });

    test('finds an xref stream after an unrelated /XRef name', () {
      const text = '%PDF-1.5\n'
          '7 0 obj\n<< /Producer (Acme) >>\nendobj\n'
          '9 0 obj\n<< /Note /XRef /Info 7 0 R /Type /XRef /Size 10 >>\n'
          'stream\nABCD\nendstream\nendobj\n%%EOF';

      final ranges = locatePdfInfoDictionaries(text);

      expect(ranges.map((range) => _slice(text, range)), [
        ' /Producer (Acme) ',
      ]);
    });

    test('ignores /Type /XRef inside a nested dictionary', () {
      const text = '%PDF-1.5\n'
          '7 0 obj\n<< /Producer (Acme) >>\nendobj\n'
          '9 0 obj\n<< /Info 7 0 R /Sub << /Type /XRef >> >>\nendobj\n%%EOF';

      expect(locatePdfInfoDictionaries(text), isEmpty);
    });

    test('finds a top-level /Type /XRef that follows a nested one', () {
      const text = '%PDF-1.5\n'
          '7 0 obj\n<< /Producer (Acme) >>\nendobj\n'
          '9 0 obj << /Sub << /Type /XRef >> /Info 7 0 R /Type /XRef >>\n'
          'endobj\n%%EOF';

      final ranges = locatePdfInfoDictionaries(text);

      expect(ranges.map((range) => _slice(text, range)), [
        ' /Producer (Acme) ',
      ]);
    });

    test('fails closed on an unterminated trailer dictionary', () {
      const text = '%PDF-1.4\ntrailer\n<< /Info 1 0 R /ID [(a)';

      expect(() => locatePdfInfoDictionaries(text), throwsFormatException);
    });

    test('scans hostile repeated trailer keywords in linear time', () {
      final text = '%PDF-1.4\n${List.filled(200000, 'trailer ').join()}';
      final stopwatch = Stopwatch()..start();

      expect(locatePdfInfoDictionaries(text), isEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('scans hostile repeated /Type /XRef names in linear time', () {
      final text = '%PDF-1.5\n1 0 obj\n<< /A 1 >>\nendobj\n'
          '${List.filled(200000, '/Type /XRef ').join()}';
      final stopwatch = Stopwatch()..start();

      expect(locatePdfInfoDictionaries(text), isEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('scans hostile repeated object headers in linear time', () {
      final text = '%PDF-1.4\n${List.filled(200000, '4 0 obj ').join()}'
          'endobj\ntrailer\n<< /Info 4 0 R >>\n%%EOF';
      final stopwatch = Stopwatch()..start();

      expect(() => locatePdfInfoDictionaries(text), throwsFormatException);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('findPdfObjectBodies', () {
    test('returns the body of every definition of the object', () {
      const text = '%PDF-1.4\n'
          '12 0 obj (Old) endobj\n'
          '112 0 obj (Other) endobj\n'
          '12 1 obj (Generation) endobj\n'
          '12 0 obj\n(New)\nendobj\n';

      final bodies = findPdfObjectBodies(text, 12, 0);

      expect(
        bodies.map((range) => _slice(text, range)),
        [' (Old) ', '\n(New)\n'],
      );
    });

    test('returns empty when the object is not defined', () {
      expect(findPdfObjectBodies('%PDF-1.4\n1 0 obj 5 endobj', 2, 0), isEmpty);
    });

    test('fails closed when a matching object has no endobj', () {
      expect(
        () => findPdfObjectBodies('%PDF-1.4\n2 0 obj (x)', 2, 0),
        throwsFormatException,
      );
    });
  });

  group('readPdfDictionaryEntries', () {
    test('reads top-level entries and skips nested values', () {
      const text = '<< /A (x (y) \\)) /B << /Title (nested) >> /C [1 2 R] '
          '/D 12 0 R /E <414243> /F /Name % comment\n/G true >>';
      const body = PdfTextRange(2, text.length - 2);

      final entries = readPdfDictionaryEntries(text, body);

      expect(
        entries.map((entry) => entry.key),
        ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      );
      final d = entries.firstWhere((entry) => entry.key == 'D');
      expect(text.substring(d.valueStart, d.valueEnd), '12 0 R');
    });
  });

  group('findPdfValueEnd', () {
    test('returns the end of a single value', () {
      const text = ' (a (b) \\)) <4142> 12 0 R /Name true ';

      expect(findPdfValueEnd(text, 1), 11);
      expect(findPdfValueEnd(text, 12), 18);
      expect(findPdfValueEnd(text, 19), 25);
      expect(findPdfValueEnd(text, 26), 31);
      expect(findPdfValueEnd(text, 32), 36);
    });

    test('returns null for malformed or missing values', () {
      expect(findPdfValueEnd('(unterminated', 0), isNull);
      expect(findPdfValueEnd('<4142', 0), isNull);
      expect(findPdfValueEnd(') x', 0), isNull);
      expect(findPdfValueEnd('', 0), isNull);
    });
  });

  group('findPdfIndirectStringRange', () {
    PdfTextRange body(String text) => PdfTextRange(0, text.length);

    test('returns the range of a single literal or hex string', () {
      const literal = '  (a (b) \\)) \n';
      final range = findPdfIndirectStringRange(literal, body(literal));
      expect(_slice(literal, range), '(a (b) \\))');

      const hex = '<4142>';
      expect(
        _slice(hex, findPdfIndirectStringRange(hex, body(hex))),
        '<4142>',
      );
    });

    test('fails closed unless the body is exactly one string', () {
      for (final text in [
        '',
        '<< /A 1 >>',
        '/Name',
        '12',
        '(a) (b)',
        '(a) 1',
        '(unterminated',
        '<4142',
        '[ (a) ]',
      ]) {
        expect(
          () => findPdfIndirectStringRange(text, body(text)),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('rejects a string that runs past the body end', () {
      const text = '(abc) trailing';
      expect(
        () => findPdfIndirectStringRange(text, const PdfTextRange(0, 3)),
        throwsFormatException,
      );
    });
  });
}

String _slice(String text, PdfTextRange range) =>
    text.substring(range.start, range.end);
