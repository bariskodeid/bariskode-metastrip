import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/viewer/data/datasources/extractors/field_helpers.dart';
import 'package:metastrip/features/viewer/domain/entities/metadata_field_entity.dart';

/// Human labels for ID3v2.3 / v2.4 frame IDs.
const Map<String, String> _v23FrameLabels = {
  'TIT2': 'Title',
  'TPE1': 'Artist',
  'TALB': 'Album',
  'TYER': 'Year',
  'TDRC': 'Year',
  'TCON': 'Genre',
  'TRCK': 'Track',
  'COMM': 'Comment',
  'TENC': 'Encoded By',
  'TSSE': 'Software',
  'TCOP': 'Copyright',
  'TPUB': 'Publisher',
  'TCOM': 'Composer',
  'WXXX': 'User URL',
  'TXXX': 'User Text',
};

/// Human labels for ID3v2.2 frame IDs (three-character variant).
const Map<String, String> _v22FrameLabels = {
  'TT2': 'Title',
  'TP1': 'Artist',
  'TAL': 'Album',
  'TYE': 'Year',
  'TCO': 'Genre',
  'TRK': 'Track',
  'COM': 'Comment',
  'TEN': 'Encoded By',
  'TSS': 'Software',
  'TCR': 'Copyright',
  'TPB': 'Publisher',
  'TCM': 'Composer',
};

/// Standard ID3v1 genre list (indices 0-147).
///
/// Index 147 follows the extended Winamp convention used by the product spec.
const List<String> _id3v1Genres = [
  'Blues',
  'Classic Rock',
  'Country',
  'Dance',
  'Disco',
  'Funk',
  'Grunge',
  'Hip-Hop',
  'Jazz',
  'Metal',
  'New Age',
  'Oldies',
  'Other',
  'Pop',
  'R&B',
  'Rap',
  'Reggae',
  'Rock',
  'Techno',
  'Industrial',
  'Alternative',
  'Ska',
  'Death Metal',
  'Pranks',
  'Soundtrack',
  'Euro-Techno',
  'Ambient',
  'Trip-Hop',
  'Vocal',
  'Jazz+Funk',
  'Fusion',
  'Trance',
  'Classical',
  'Instrumental',
  'Acid',
  'House',
  'Game',
  'Sound Clip',
  'Gospel',
  'Noise',
  'AlternRock',
  'Bass',
  'Soul',
  'Punk',
  'Space',
  'Meditative',
  'Instrumental Pop',
  'Instrumental Rock',
  'Ethnic',
  'Gothic',
  'Darkwave',
  'Techno-Industrial',
  'Electronic',
  'Pop-Folk',
  'Eurodance',
  'Dream',
  'Southern Rock',
  'Comedy',
  'Cult',
  'Gangsta',
  'Top 40',
  'Christian Rap',
  'Pop/Funk',
  'Jungle',
  'Native American',
  'Cabaret',
  'New Wave',
  'Psychadelic',
  'Rave',
  'Showtunes',
  'Trailer',
  'Lo-Fi',
  'Tribal',
  'Acid Punk',
  'Acid Jazz',
  'Polka',
  'Retro',
  'Musical',
  'Rock & Roll',
  'Hard Rock',
  'Folk',
  'Folk-Rock',
  'National Folk',
  'Swing',
  'Fast Fusion',
  'Bebop',
  'Latin',
  'Revival',
  'Celtic',
  'Bluegrass',
  'Avantgarde',
  'Gothic Rock',
  'Progressive Rock',
  'Psychedelic Rock',
  'Symphonic Rock',
  'Slow Rock',
  'Big Band',
  'Chorus',
  'Easy Listening',
  'Acoustic',
  'Humour',
  'Speech',
  'Chanson',
  'Opera',
  'Chamber Music',
  'Sonata',
  'Symphony',
  'Booty Bass',
  'Primus',
  'Porn Groove',
  'Satire',
  'Slow Jam',
  'Club',
  'Tango',
  'Samba',
  'Folklore',
  'Ballad',
  'Power Ballad',
  'Rhythmic Soul',
  'Freestyle',
  'Duet',
  'Punk Rock',
  'Drum Solo',
  'A Capella',
  'Euro-House',
  'Dance Hall',
  'Goa',
  'Drum & Bass',
  'Club-House',
  'Hardcore',
  'Terror',
  'Indie',
  'BritPop',
  'Synthpop',
];

/// Maximum number of frames scanned before giving up defensively.
const int _maxFrames = 64;

/// Extracts ID3v2 and ID3v1.1 metadata from raw audio [bytes].
///
/// Walks the ID3v2 frame stream (v2.2/2.3/2.4) and the trailing 128-byte
/// ID3v1.1 tag, resolving text encodings, genre indices and comment payloads.
/// Returns a single status field when no tag exists or when the bytes cannot
/// be parsed; this function never throws.
Future<List<MetadataFieldEntity>> extractId3(Uint8List bytes) async {
  try {
    final fields = <MetadataFieldEntity>[];
    final hasV2 = _hasId3v2Header(bytes);
    if (hasV2 && !_parseId3v2(bytes, fields)) {
      return [
        statusField('Audio ID3', 'Status', 'Unable to parse ID3 metadata'),
      ];
    }
    if (_hasId3v1Header(bytes)) {
      _parseId3v1(bytes, fields);
    }
    if (fields.isNotEmpty || hasV2 || _hasId3v1Header(bytes)) {
      if (fields.isEmpty) {
        return [
          statusField('Audio ID3', 'Status', 'No ID3 metadata found'),
        ];
      }
      return fields;
    }
    return [statusField('Audio ID3', 'Status', 'No ID3 metadata found')];
  } catch (_) {
    return [
      statusField('Audio ID3', 'Status', 'Unable to parse ID3 metadata'),
    ];
  }
}

/// Whether [bytes] starts with a `ID3` header marker.
bool _hasId3v2Header(Uint8List bytes) {
  return bytes.length >= 10 &&
      bytes[0] == 0x49 && // 'I'
      bytes[1] == 0x44 && // 'D'
      bytes[2] == 0x33; // '3'
}

/// Whether [bytes] ends with a `TAG` ID3v1 marker.
bool _hasId3v1Header(Uint8List bytes) {
  if (bytes.length < 128) return false;
  final offset = bytes.length - 128;
  return bytes[offset] == 0x54 && // 'T'
      bytes[offset + 1] == 0x41 && // 'A'
      bytes[offset + 2] == 0x47; // 'G'
}

/// Parses the ID3v2 tag in [bytes], appending fields to [fields].
///
/// Returns false when the header declares a tag larger than the available
/// bytes (truncated or corrupt), in which case scanning cannot be trusted.
bool _parseId3v2(Uint8List bytes, List<MetadataFieldEntity> fields) {
  final version = bytes[3];
  if (version != 2 && version != 3 && version != 4) return false;

  final tagSize = _synchsafe(bytes, 6);
  final tagEnd = 10 + tagSize;
  if (tagSize < 0 || tagEnd > bytes.length) return false;

  final frameIdLength = version == 2 ? 3 : 4;
  final hasFlags = version != 2;
  final labels = version == 2 ? _v22FrameLabels : _v23FrameLabels;

  var offset = 10;
  var frameCount = 0;
  while (offset + frameIdLength <= tagEnd && frameCount < _maxFrames) {
    if (!_isValidFrameId(bytes, offset, frameIdLength)) break;

    final sizeOffset = offset + frameIdLength;
    final sizeLength = hasFlags ? 4 : 3;
    final headerLength = sizeLength + (hasFlags ? 2 : 0);
    if (sizeOffset + headerLength > tagEnd) break;

    final size = switch (version) {
      2 => _bigEndian3(bytes, sizeOffset),
      3 => _bigEndian4(bytes, sizeOffset),
      _ => _synchsafe(bytes, sizeOffset),
    };

    final dataOffset = sizeOffset + headerLength;
    if (dataOffset + size > bytes.length) break;

    final id =
        String.fromCharCodes(bytes.sublist(offset, offset + frameIdLength));
    final label = labels[id];
    if (label != null) {
      final data = bytes.sublist(dataOffset, dataOffset + size);
      var value = id == 'COMM' || id == 'COM'
          ? _decodeComment(data)
          : _decodeTextFrame(data);
      value = value.trim();
      if (id == 'TCON' || id == 'TCO') value = _resolveGenre(value);
      if ((id == 'TXXX' || id == 'WXXX') && value.contains('\u0000')) {
        value = value.replaceAll('\u0000', ' ');
      }
      if (value.isNotEmpty) {
        fields.add(
          MetadataFieldEntity(
            section: 'Audio ID3',
            label: label,
            value: truncateMetadataValue(value),
            isPrivacySensitive: isTextPrivacySensitive(label),
          ),
        );
      }
    }

    frameCount++;
    offset = dataOffset + size;
  }
  return true;
}

/// Whether [bytes] at [offset] holds a printable ASCII frame ID.
bool _isValidFrameId(Uint8List bytes, int offset, int length) {
  for (var i = 0; i < length; i++) {
    final byte = bytes[offset + i];
    if (byte < 0x20 || byte > 0x7E) return false;
  }
  return true;
}

/// Reads a four-byte synchsafe integer (7 bits per byte) at [offset].
int _synchsafe(Uint8List bytes, int offset) {
  return ((bytes[offset] & 0x7F) << 21) |
      ((bytes[offset + 1] & 0x7F) << 14) |
      ((bytes[offset + 2] & 0x7F) << 7) |
      (bytes[offset + 3] & 0x7F);
}

/// Reads a three-byte big-endian integer at [offset].
int _bigEndian3(Uint8List bytes, int offset) {
  return (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
}

/// Reads a four-byte big-endian integer at [offset].
int _bigEndian4(Uint8List bytes, int offset) {
  return ByteData.sublistView(bytes, offset, offset + 4).getUint32(
    0,
    Endian.big,
  );
}

/// Decodes a text frame whose [data] starts with an encoding byte.
///
/// Supports Latin-1, UTF-16 (with or without BOM), UTF-16BE and UTF-8 and
/// strips any trailing NUL characters.
String _decodeTextFrame(Uint8List data) {
  if (data.isEmpty) return '';
  return _stripTrailingNulls(_decodePayload(data.sublist(1), data[0]));
}

/// Decodes a COMM/COM frame body: encoding, language, description, text.
String _decodeComment(Uint8List data) {
  if (data.length < 4) return '';
  final encoding = data[0];
  final terminator = encoding == 1 || encoding == 2 ? 2 : 1;
  final cursor = _skipDescription(data, 4, terminator);
  return _stripTrailingNulls(_decodePayload(data.sublist(cursor), encoding));
}

/// Whether the terminator pattern of [width] bytes starts at [offset].
bool _isTerminatorAt(Uint8List data, int offset, int width) {
  if (offset + width > data.length) return false;
  for (var i = 0; i < width; i++) {
    if (data[offset + i] != 0) return false;
  }
  return true;
}

/// Returns the index just past the null-terminated description in [data].
int _skipDescription(Uint8List data, int start, int width) {
  var cursor = start;
  while (cursor < data.length && !_isTerminatorAt(data, cursor, width)) {
    cursor++;
  }
  if (cursor + width > data.length) return data.length;
  return cursor + width;
}

/// Decodes [payload] (without encoding byte) using [encoding].
String _decodePayload(Uint8List payload, int encoding) {
  switch (encoding) {
    case 0:
      return latin1.decode(payload);
    case 1:
      return _decodeUtf16(payload);
    case 2:
      return _decodeUtf16Units(payload, 0, bigEndian: true);
    default:
      return utf8.decode(payload, allowMalformed: true);
  }
}

/// Decodes UTF-16 [bytes], honoring a leading BOM and defaulting to LE.
String _decodeUtf16(Uint8List bytes) {
  if (bytes.length < 2) return '';
  if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _decodeUtf16Units(bytes, 2, bigEndian: false);
  }
  if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _decodeUtf16Units(bytes, 2, bigEndian: true);
  }
  return _decodeUtf16Units(bytes, 0, bigEndian: false);
}

/// Decodes UTF-16 code units starting at [start] with the given [bigEndian].
///
/// Surrogate pairs pass through naturally because code units are assembled
/// into the string with [String.fromCharCodes].
String _decodeUtf16Units(
  Uint8List bytes,
  int start, {
  required bool bigEndian,
}) {
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    final high = bytes[i];
    final low = bytes[i + 1];
    units.add(bigEndian ? (high << 8) | low : (low << 8) | high);
  }
  return String.fromCharCodes(units);
}

/// Removes trailing NUL code units from [value].
String _stripTrailingNulls(String value) {
  var end = value.length;
  while (end > 0 && value.codeUnitAt(end - 1) == 0) {
    end--;
  }
  return value.substring(0, end);
}

/// Maps a numeric genre value to its standard name, keeping [raw] otherwise.
String _resolveGenre(String raw) {
  final index = int.tryParse(raw);
  if (index == null || index < 0 || index >= _id3v1Genres.length) return raw;
  return _id3v1Genres[index];
}

/// Parses the trailing 128-byte ID3v1.1 tag, appending fields to [fields].
void _parseId3v1(Uint8List bytes, List<MetadataFieldEntity> fields) {
  final tag = bytes.length - 128;
  void add(String label, String value) {
    final trimmed = value.replaceAll('\u0000', '').trim();
    if (trimmed.isEmpty) return;
    fields.add(
      MetadataFieldEntity(
        section: 'Audio ID3',
        label: label,
        value: truncateMetadataValue(trimmed),
        isPrivacySensitive: isTextPrivacySensitive(label),
      ),
    );
  }

  add('Title', latin1.decode(bytes.sublist(tag + 3, tag + 33)));
  add('Artist', latin1.decode(bytes.sublist(tag + 33, tag + 63)));
  add('Album', latin1.decode(bytes.sublist(tag + 63, tag + 93)));
  add('Year', latin1.decode(bytes.sublist(tag + 93, tag + 97)));

  final commentBytes = bytes.sublist(tag + 97, tag + 125);
  add('Comment', latin1.decode(commentBytes));

  if (bytes[tag + 125] == 0 && bytes[tag + 126] != 0) {
    add('Track', '${bytes[tag + 126]}');
  }

  final genre = bytes[tag + 127];
  add(
    'Genre',
    genre < _id3v1Genres.length ? _id3v1Genres[genre] : '$genre',
  );
}
