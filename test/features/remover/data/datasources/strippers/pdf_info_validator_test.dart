import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_validator.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';

void main() {
  group('validateGeneratedPdfInfoMutation', () {
    test('accepts only expected literal, hex, and token blanking', () {
      final input = _info('/Title (Secret)/Subject <414243>/Trapped /True');
      final output = _info('/Title (      )/Subject <      >/Trapped /X   ');

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('reports selected key already absent', () {
      final bytes = _info('/Title (Keep)');

      expect(
        () => validateGeneratedPdfInfoMutation(
          bytes,
          bytes,
          selectedKeys: {'Author'},
        ),
        returnsNormally,
      );
    });

    test('rejects malformed requested values', () {
      final input = _info('/Title (unterminated');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('rejects corruption outside a recognized value', () {
      final input = _info('/Author (Ada)');
      final output = Uint8List.fromList(input);
      output[6] = 0x39;

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        throwsFormatException,
      );
    });

    test('rejects an unblanked recognized value', () {
      final input = _info('/Author (Ada)');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('does not treat a longer PDF name as a recognized key', () {
      final input = _info(
        '/AuthorName (Ada)/Author+Private (Bea)/Author#46oo (Cyd)',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        returnsNormally,
      );
    });

    test('preserves PDF name boundaries and accepts a name-token value', () {
      final input = _info(
        '/Title+Private (keep)/Title#46oo (keep)/Title (remove)/Trapped /True',
      );
      final output = _info(
        '/Title+Private (keep)/Title#46oo (keep)/Title (      )/Trapped /X   ',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('preserves a valid neutral name object for name-token values', () {
      final input = _info('/Trapped /CustomName');
      final output = _info('/Trapped /X         ');

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('rejects blanking the name-token delimiter or neutral name', () {
      final input = _info('/Trapped /True');
      final invalid = _info('/Trapped      ');

      expect(
        () => validateGeneratedPdfInfoMutation(input, invalid),
        throwsFormatException,
      );
    });

    test('counts longer-name candidates against the shared scan cap', () {
      final markers = List.filled(
        maxPdfInfoValueOccurrences + 1,
        '/TitleFoo (x)',
      ).join();
      final input = _info(markers);

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('accepts a value that contains another key name', () {
      const value = '/Author (Ada)';
      final input = _literalPdf('Title', value);
      final output = _blankedLiteralPdf('Title', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('blanks a value that contains a name-token key fully', () {
      const value = '/Title /True';
      final input = _literalPdf('Author', value);
      final output = _blankedLiteralPdf('Author', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('accepts escaped closing parentheses in literal values', () {
      final input = _info(r'/Author (Ada\) Smith)');
      final output = _info('/Author (           )');

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('accepts fully blanked nested literal values', () {
      const value = 'Outer (Inner (Deep)) End';
      final input = _literalPdf('Title', value);
      final output = _blankedLiteralPdf('Title', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('accepts escaped parentheses and backslashes inside nested values',
        () {
      const value = r'Outer \(literal\) (Inner\\Path\) Tail) End';
      final input = _literalPdf('Author', value);
      final output = _blankedLiteralPdf('Author', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('accepts deeply nested literal values without recursion', () {
      const depth = 10000;
      final value = '${_repeat('(', depth)}Secret${_repeat(')', depth)}';
      final input = _literalPdf('Subject', value);
      final output = _blankedLiteralPdf('Subject', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('rejects more than the shared recognized occurrence cap', () {
      final markers = List.filled(
        maxPdfInfoValueOccurrences + 1,
        '/Title (x)',
      ).join();
      final input = _info(markers);
      final output = _info(markers.replaceAll('(x)', '( )'));

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        throwsFormatException,
      );
    });

    test('rejects blanking a /Title outside the Info dictionary', () {
      const template = '%PDF-1.4\n'
          '3 0 obj << /Title (OUTLINE) >> endobj\n'
          '4 0 obj << /Title (INFO) >> endobj\n'
          'trailer\n<< /Info 4 0 R >>\n%%EOF';
      final input = _bytes(
        template.replaceAll('OUTLINE', 'Chapter').replaceAll('INFO', 'Secret'),
      );
      final output = _bytes(
        template.replaceAll('OUTLINE', '       ').replaceAll('INFO', '      '),
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        throwsFormatException,
      );
    });

    test('accepts a blanked indirect Info string object', () {
      const template = '%PDF-1.4\n'
          '4 0 obj << /Title 12 0 R >> endobj\n'
          '12 0 obj (VALUE) endobj\n'
          'trailer\n<< /Info 4 0 R >>\n%%EOF';
      final input = _bytes(template.replaceAll('VALUE', 'Secret'));
      final output = _bytes(template.replaceAll('VALUE', '      '));

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('rejects an unresolvable indirect Info value', () {
      final input = _info('/Title 12 0 R');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });
  });
}

Uint8List _bytes(String value) => Uint8List.fromList(latin1.encode(value));

/// A PDF whose trailer references object 1 holding the Info [entries].
Uint8List _info(String entries) => _bytes(
      '%PDF-1.4\n1 0 obj\n<<$entries>>\nendobj\n'
      'trailer\n<< /Info 1 0 R >>\n%%EOF',
    );

Uint8List _literalPdf(String key, String value) => _info('/$key ($value)');

Uint8List _blankedLiteralPdf(String key, int valueLength) =>
    _literalPdf(key, _repeat(' ', valueLength));

String _repeat(String value, int count) => List.filled(count, value).join();
