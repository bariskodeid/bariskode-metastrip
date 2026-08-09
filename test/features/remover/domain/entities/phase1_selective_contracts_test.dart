import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';
import 'package:metastrip/features/remover/domain/entities/strip_policy.dart';
import 'package:metastrip/features/remover/domain/entities/strip_report.dart';

void main() {
  group('MetadataFieldId', () {
    test('exposes fixed PDF DocInfo IDs', () {
      expect(MetadataFieldId.pdfInfoAuthor.value, 'pdf.info.author');
      expect(MetadataFieldId.pdfInfoTitle.value, 'pdf.info.title');
    });

    test('uses canonical direct Vorbis comment IDs', () {
      final id = MetadataFieldId.vorbisComment('  title ');
      expect(id.value, 'vorbis.comment.TITLE');
      expect(MetadataFieldId.parse(id.value), id);
      expect(id.isVorbisComment, isTrue);
      expect(id.vorbisCommentKey, 'TITLE');
      expect(
        () => MetadataFieldId.vorbisComment('bad=key'),
        throwsArgumentError,
      );
      expect(
        () => MetadataFieldId.parse('vorbis.comment.title'),
        throwsFormatException,
      );
    });

    test('round-trips a PNG text keyword through its stable ID', () {
      const keyword = 'Creation Time / v2';

      final fieldId = MetadataFieldId.pngText(keyword);
      final parsed = MetadataFieldId.parse(fieldId.value);

      expect(fieldId.value, startsWith('png.text.'));
      expect(parsed, fieldId);
      expect(parsed.pngKeyword, keyword);
    });

    test('rejects malformed PNG keywords before encoding', () {
      for (final keyword in [
        '',
        ' leading',
        'trailing ',
        'two  spaces',
        'line\nbreak',
        'null\u0000byte',
        'emoji \u{1F642}',
        'x' * 80,
      ]) {
        expect(
          () => MetadataFieldId.pngText(keyword),
          throwsArgumentError,
          reason: keyword,
        );
      }
    });

    test('rejects oversized and malformed encoded PNG IDs before decoding', () {
      expect(
        () => MetadataFieldId.parse('png.text.${'A' * 107}'),
        throwsFormatException,
      );
      expect(
        () => MetadataFieldId.parse('png.text.A==='),
        throwsFormatException,
      );
      expect(
        () => MetadataFieldId.parse('png.text.AA'),
        throwsFormatException,
      );
    });
  });

  group('StripPolicy', () {
    test('supported cleanup is explicit and selects no individual IDs', () {
      const policy = StripPolicy.supportedCleanup();

      expect(policy.mode, StripPolicyMode.supportedCleanup);
      expect(policy.selectedFieldIds, isEmpty);
    });

    test('selective cleanup requires at least one field ID', () {
      expect(
        () => StripPolicy.selective(fieldIds: const <MetadataFieldId>{}),
        throwsArgumentError,
      );
    });

    test('selective cleanup snapshots an immutable ID set', () {
      final ids = <MetadataFieldId>{MetadataFieldId.pdfInfoAuthor};
      final policy = StripPolicy.selective(fieldIds: ids);
      ids.add(MetadataFieldId.pdfInfoTitle);

      expect(policy.mode, StripPolicyMode.selective);
      expect(policy.selectedFieldIds, {MetadataFieldId.pdfInfoAuthor});
      expect(
        () => policy.selectedFieldIds.add(MetadataFieldId.pdfInfoTitle),
        throwsUnsupportedError,
      );
    });
  });

  test('StripReport records requested, removed, absent, and warning facts', () {
    final report = StripReport(
      requestedFieldIds: const {
        MetadataFieldId.pdfInfoAuthor,
        MetadataFieldId.pdfInfoTitle,
      },
      removedFieldIds: const {MetadataFieldId.pdfInfoAuthor},
      alreadyAbsentFieldIds: const {MetadataFieldId.pdfInfoTitle},
      warnings: const ['Title was already absent'],
    );

    expect(report.requestedFieldIds, {
      MetadataFieldId.pdfInfoAuthor,
      MetadataFieldId.pdfInfoTitle,
    });
    expect(report.removedFieldIds, {MetadataFieldId.pdfInfoAuthor});
    expect(report.alreadyAbsentFieldIds, {MetadataFieldId.pdfInfoTitle});
    expect(report.warnings, ['Title was already absent']);
  });

  test('StripReport snapshots inputs and has value equality', () {
    final requested = <MetadataFieldId>{MetadataFieldId.pdfInfoAuthor};
    final removed = <MetadataFieldId>{MetadataFieldId.pdfInfoAuthor};
    final absent = <MetadataFieldId>{MetadataFieldId.pdfInfoTitle};
    final unsupported = <MetadataFieldId>{MetadataFieldId.pdfInfoCreator};
    final warnings = <String>['warning'];
    final report = StripReport(
      requestedFieldIds: requested,
      removedFieldIds: removed,
      alreadyAbsentFieldIds: absent,
      unsupportedFieldIds: unsupported,
      warnings: warnings,
    );

    requested.add(MetadataFieldId.pdfInfoTitle);
    removed.clear();
    absent.clear();
    unsupported.clear();
    warnings.add('changed');

    expect(report.requestedFieldIds, {MetadataFieldId.pdfInfoAuthor});
    expect(report.removedFieldIds, {MetadataFieldId.pdfInfoAuthor});
    expect(report.alreadyAbsentFieldIds, {MetadataFieldId.pdfInfoTitle});
    expect(report.unsupportedFieldIds, {MetadataFieldId.pdfInfoCreator});
    expect(report.warnings, ['warning']);
    expect(
      report,
      StripReport(
        requestedFieldIds: const {MetadataFieldId.pdfInfoAuthor},
        removedFieldIds: const {MetadataFieldId.pdfInfoAuthor},
        alreadyAbsentFieldIds: const {MetadataFieldId.pdfInfoTitle},
        unsupportedFieldIds: const {MetadataFieldId.pdfInfoCreator},
        warnings: const ['warning'],
      ),
    );
    expect(
      () => report.requestedFieldIds.add(MetadataFieldId.pdfInfoTitle),
      throwsUnsupportedError,
    );
    expect(() => report.warnings.add('changed'), throwsUnsupportedError);
  });

  test('StripReport exposes explicit consistent verification outcomes', () {
    final verified = StripReport(
      verificationOutcome: StripVerificationOutcome.verified,
      outputValidated: true,
    );
    final attempted = StripReport(
      verificationOutcome: StripVerificationOutcome.attemptedUnverified,
    );
    final notAttempted = StripReport();

    expect(verified.verificationOutcome, StripVerificationOutcome.verified);
    expect(verified.outputValidated, isTrue);
    expect(
      attempted.verificationOutcome,
      StripVerificationOutcome.attemptedUnverified,
    );
    expect(attempted.outputValidated, isFalse);
    expect(
      notAttempted.verificationOutcome,
      StripVerificationOutcome.notAttempted,
    );
    expect(
      () => StripReport(
        verificationOutcome: StripVerificationOutcome.verified,
      ),
      throwsArgumentError,
    );
    expect(
      () => StripReport(
        verificationOutcome: StripVerificationOutcome.attemptedUnverified,
        outputValidated: true,
      ),
      throwsArgumentError,
    );
  });
}
