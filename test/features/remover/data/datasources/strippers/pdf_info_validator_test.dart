import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_validator.dart';
import 'package:metastrip/features/remover/data/datasources/strippers/pdf_info_value_parser.dart';

void main() {
  group('validateGeneratedPdfInfoMutation', () {
    test('accepts only expected literal, hex, and token blanking', () {
      final input = _bytes(
        '%PDF-1.4\n/Title (Secret)/Subject <414243>/Trapped /True\n%%EOF',
      );
      final output = _bytes(
        '%PDF-1.4\n/Title (      )/Subject <      >/Trapped /X   \n%%EOF',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('reports selected key already absent', () {
      final bytes = _bytes('%PDF-1.4\n/Title (Keep)\n%%EOF');

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
      final input = _bytes('%PDF-1.4\n/Title (unterminated\n%%EOF');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('rejects corruption outside a recognized value', () {
      final input = _bytes('%PDF-1.4\n/Author (Ada)\n%%EOF');
      final output = Uint8List.fromList(input);
      output[6] = 0x39;

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        throwsFormatException,
      );
    });

    test('rejects an unblanked recognized value', () {
      final input = _bytes('%PDF-1.4\n/Author (Ada)\n%%EOF');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('does not treat a longer PDF name as a recognized key', () {
      final input = _bytes(
        '%PDF-1.4\n/AuthorName (Ada)/Author+Private (Bea)'
        '/Author#46oo (Cyd)\n%%EOF',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        returnsNormally,
      );
    });

    test('preserves PDF name boundaries and accepts a name-token value', () {
      final input = _bytes(
        '%PDF-1.4\n/Title+Private (keep)/Title#46oo (keep)'
        '/Title (remove)/Trapped /True\n%%EOF',
      );
      final output = _bytes(
        '%PDF-1.4\n/Title+Private (keep)/Title#46oo (keep)'
        '/Title (      )/Trapped /X   \n%%EOF',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('preserves a valid neutral name object for name-token values', () {
      final input = _bytes('%PDF-1.4\n/Trapped /CustomName>>\n%%EOF');
      final output = _bytes('%PDF-1.4\n/Trapped /X         >>\n%%EOF');

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('rejects blanking the name-token delimiter or neutral name', () {
      final input = _bytes('%PDF-1.4\n/Trapped /True\n%%EOF');
      final invalid = _bytes('%PDF-1.4\n/Trapped      \n%%EOF');

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
      final input = _bytes('%PDF-1.4\n$markers\n%%EOF');

      expect(
        () => validateGeneratedPdfInfoMutation(input, input),
        throwsFormatException,
      );
    });

    test('accepts overlapping recognized mutation ranges', () {
      const value = '/Author (Ada)';
      final input = _literalPdf('Title', value);
      final output = _blankedLiteralPdf('Title', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('later outer mutation suppresses an earlier nested replacement', () {
      const value = '/Title /True';
      final input = _literalPdf('Author', value);
      final output = _blankedLiteralPdf('Author', value.length);

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        returnsNormally,
      );
    });

    test('accepts escaped closing parentheses in literal values', () {
      final input = _bytes(r'%PDF-1.4\n/Author (Ada\) Smith)\n%%EOF');
      final output = _bytes(r'%PDF-1.4\n/Author (           )\n%%EOF');

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
      final input = _bytes('%PDF-1.4\n$markers\n%%EOF');
      final output = _bytes(
        '%PDF-1.4\n${markers.replaceAll('(x)', '( )')}\n%%EOF',
      );

      expect(
        () => validateGeneratedPdfInfoMutation(input, output),
        throwsFormatException,
      );
    });
  });
}

Uint8List _bytes(String value) => Uint8List.fromList(latin1.encode(value));

Uint8List _literalPdf(String key, String value) =>
    _bytes('%PDF-1.4\n/$key ($value)\n%%EOF');

Uint8List _blankedLiteralPdf(String key, int valueLength) =>
    _literalPdf(key, _repeat(' ', valueLength));

String _repeat(String value, int count) => List.filled(count, value).join();
