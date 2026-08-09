import 'dart:convert';
import 'dart:typed_data';

import 'package:metastrip/features/remover/domain/entities/metadata_field_id.dart';

const _maxInputBytes = 8 * 1024 * 1024;
const _maxPages = 64;
const _maxPackets = 192;
const _maxComments = 128;
const _maxVendorBytes = 64 * 1024;
const _maxEntryBytes = 64 * 1024;
const _maxOutputBytes = 8 * 1024 * 1024;

/// Result of the disabled, bounded Ogg Vorbis selective-removal POC.
class OggVorbisSelectivePocResult {
  const OggVorbisSelectivePocResult({
    required this.bytes,
    required this.matchedKeys,
  });

  final Uint8List bytes;
  final Set<String> matchedKeys;
}

/// Removes selected Vorbis comment keys from a deliberately narrow Ogg POC.
///
/// This is intentionally not a remover capability: it is not routed through
/// the registry or datasource. It accepts only one logical stream, version 0
/// pages whose packets are wholly contained by one page. The comment packet
/// itself must be a single-page `\x03vorbis` packet. Unsupported continued or
/// cross-page packets, malformed structures, and streams with another serial
/// fail closed.
/// The first page must carry BOS and no later page may carry BOS. EOS is
/// permitted only on the final page; EOS is not required for this bounded POC.
OggVorbisSelectivePocResult stripOggVorbisCommentsSelectivePoc(
  Uint8List bytes, {
  required Set<String> selectedKeys,
}) {
  if (selectedKeys.isEmpty) {
    throw const FormatException('No metadata fields selected');
  }
  final wanted = <String>{};
  try {
    for (final key in selectedKeys) {
      wanted.add(MetadataFieldId.normalizeVorbisCommentKey(key));
    }
  } on ArgumentError catch (error) {
    throw FormatException('Invalid selected Vorbis key: $error');
  }

  final pages = _parsePages(bytes);
  final packets = <_PacketRef>[];
  for (final page in pages) {
    var cursor = page.payloadStart;
    var packetStart = cursor;
    for (final lace in page.laces) {
      cursor += lace;
      if (lace < 255) {
        packets.add(_PacketRef(page, packetStart, cursor));
        packetStart = cursor;
      }
    }
  }
  if (packets.length > _maxPackets ||
      packets.isEmpty ||
      !_hasPrefix(bytes, packets.first.start, [1, ...'vorbis'.codeUnits])) {
    throw const FormatException('Not a strict single-stream Vorbis Ogg stream');
  }

  final outputPages = <Uint8List>[];
  final matched = <String>{};
  var foundComment = false;
  for (final page in pages) {
    final pagePackets = packets.where((packet) => identical(packet.page, page));
    final payload = BytesBuilder(copy: false);
    final laces = <int>[];
    for (final packet in pagePackets) {
      var packetBytes = bytes.sublist(packet.start, packet.end);
      if (_hasPrefix(packetBytes, 0, [0x03, ...'vorbis'.codeUnits])) {
        if (foundComment) {
          throw const FormatException('Multiple Vorbis comment packets');
        }
        foundComment = true;
        packetBytes = _rewriteComment(packetBytes, wanted, matched);
      }
      payload.add(packetBytes);
      final packetLaces = _lace(packetBytes.length);
      laces.addAll(packetLaces);
    }
    outputPages.add(_writePage(page, laces, payload.takeBytes()));
  }
  if (!foundComment) {
    throw const FormatException('Vorbis comment packet not found');
  }
  final result =
      Uint8List.fromList(outputPages.expand((page) => page).toList());
  if (result.length > _maxOutputBytes) {
    throw const FormatException('Ogg POC output exceeds bounded size');
  }
  _validatePreservedStructure(bytes, result, pages);
  _validateOggVorbisPoc(result, wanted);
  return OggVorbisSelectivePocResult(bytes: result, matchedKeys: matched);
}

class _Page {
  _Page(this.start, this.end, this.payloadStart, this.laces, this.header);
  final int start;
  final int end;
  final int payloadStart;
  final List<int> laces;
  final Uint8List header;
}

class _PacketRef {
  _PacketRef(this.page, this.start, this.end);
  final _Page page;
  final int start;
  final int end;
}

List<_Page> _parsePages(Uint8List bytes) {
  if (bytes.length > _maxInputBytes) {
    throw const FormatException('Ogg POC input exceeds bounded size');
  }
  final pages = <_Page>[];
  var offset = 0;
  int? serial;
  var sequence = 0;
  while (offset < bytes.length) {
    if (pages.length >= _maxPages) {
      throw const FormatException('Ogg POC page limit exceeded');
    }
    if (offset + 27 > bytes.length ||
        !_hasPrefix(bytes, offset, [0x4f, 0x67, 0x67, 0x53])) {
      throw const FormatException('Malformed Ogg page');
    }
    if (bytes[offset + 4] != 0 || (bytes[offset + 5] & 1) != 0) {
      throw const FormatException('Continued Ogg packets are unsupported');
    }
    final headerType = bytes[offset + 5];
    if (pages.isEmpty && headerType & 2 == 0) {
      throw const FormatException('Ogg stream must begin with BOS');
    }
    if (pages.isNotEmpty && headerType & 2 != 0) {
      throw const FormatException('Ogg BOS is only valid on the first page');
    }
    final pageSerial = _le32At(bytes, offset + 14);
    serial ??= pageSerial;
    if (serial != pageSerial || _le32At(bytes, offset + 18) != sequence++) {
      throw const FormatException('Ogg is not one ordered logical stream');
    }
    final count = bytes[offset + 26];
    final tableStart = offset + 27;
    final payloadStart = tableStart + count;
    if (count == 0 || payloadStart > bytes.length) {
      throw const FormatException('Truncated Ogg lacing table');
    }
    var end = payloadStart;
    final laces = <int>[];
    for (var i = 0; i < count; i++) {
      final lace = bytes[tableStart + i];
      laces.add(lace);
      end += lace;
    }
    if (laces.isNotEmpty && laces.last == 255) {
      throw const FormatException('Cross-page Ogg packets are unsupported');
    }
    if (end > bytes.length) {
      throw const FormatException('Truncated Ogg page payload');
    }
    final storedCrc = _le32At(bytes, offset + 22);
    if (_crc(bytes.sublist(offset, end)) != storedCrc) {
      throw const FormatException('Invalid Ogg page CRC');
    }
    pages.add(_Page(
        offset, end, payloadStart, laces, bytes.sublist(offset, offset + 27)));
    offset = end;
  }
  if (pages.isEmpty) throw const FormatException('Empty Ogg stream');
  for (var i = 0; i < pages.length - 1; i++) {
    if (pages[i].header[5] & 4 != 0) {
      throw const FormatException('Ogg EOS must be on the final page');
    }
  }
  return pages;
}

Uint8List _rewriteComment(
    Uint8List packet, Set<String> wanted, Set<String> matched) {
  const markerLength = 7;
  if (packet.length < markerLength + 8) {
    throw const FormatException('Malformed Vorbis comment packet');
  }
  final view = ByteData.sublistView(packet);
  final vendorLength = view.getUint32(markerLength, Endian.little);
  var offset = markerLength + 4;
  if (vendorLength > _maxVendorBytes ||
      vendorLength > packet.length - offset - 4) {
    throw const FormatException('Malformed Vorbis vendor');
  }
  final vendorEnd = offset + vendorLength;
  _decodeUtf8(packet.sublist(offset, vendorEnd), 'Vorbis vendor');
  offset = vendorEnd;
  final count = view.getUint32(offset, Endian.little);
  offset += 4;
  if (count > _maxComments) {
    throw const FormatException('Vorbis comment count exceeds cap');
  }
  final kept = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    if (offset + 4 > packet.length) {
      throw const FormatException('Malformed Vorbis comment list');
    }
    final length = view.getUint32(offset, Endian.little);
    offset += 4;
    if (length > _maxEntryBytes || length > packet.length - offset) {
      throw const FormatException('Malformed Vorbis comment entry');
    }
    final entry = Uint8List.sublistView(packet, offset, offset + length);
    offset += length;
    final equals = entry.indexOf(0x3d);
    if (equals <= 0) {
      throw const FormatException('Malformed Vorbis comment entry');
    }
    final decoded = _decodeUtf8(entry, 'Vorbis comment entry');
    final key = _normalize(decoded.substring(0, decoded.indexOf('=')));
    if (wanted.contains(key)) {
      matched.add(key);
    } else {
      kept.add(entry);
    }
  }
  if (offset != packet.length) {
    throw const FormatException('Trailing Vorbis comment bytes');
  }
  final body = BytesBuilder(copy: false)
    ..add(packet.sublist(markerLength, vendorEnd))
    ..add(_le32(kept.length));
  for (final entry in kept) {
    body
      ..add(_le32(entry.length))
      ..add(entry);
  }
  return Uint8List.fromList(
      [...packet.sublist(0, markerLength), ...body.takeBytes()]);
}

Uint8List _writePage(_Page page, List<int> laces, Uint8List payload) {
  final header = Uint8List.fromList(page.header);
  header[26] = laces.length;
  final result = Uint8List.fromList([...header, ...laces, ...payload]);
  result.fillRange(22, 26, 0);
  final crc = _crc(result);
  ByteData.sublistView(result).setUint32(22, crc, Endian.little);
  return result;
}

void _validateOggVorbisPoc(Uint8List bytes, Set<String> wanted) {
  final pages = _parsePages(bytes);
  for (final packet in _packetsForPages(bytes, pages)) {
    if (_hasPrefix(packet, 0, [0x03, ...'vorbis'.codeUnits])) {
      final keys = _readKeys(packet);
      if (keys.any(wanted.contains)) {
        throw const FormatException('Selected Vorbis key survived validation');
      }
    }
  }
}

void _validatePreservedStructure(
  Uint8List before,
  Uint8List after,
  List<_Page> beforePages,
) {
  final afterPages = _parsePages(after);
  if (beforePages.length != afterPages.length) {
    throw const FormatException('Ogg page count changed during rewrite');
  }
  for (var i = 0; i < beforePages.length; i++) {
    final old = beforePages[i];
    final rewritten = afterPages[i];
    for (final index in [4, 5, 14, 15, 16, 17, 18, 19, 20, 21]) {
      if (old.header[index] != rewritten.header[index]) {
        throw const FormatException('Ogg structural header changed');
      }
    }
  }
  final oldPackets = _packetsForPages(before, beforePages);
  final newPackets = _packetsForPages(after, afterPages);
  if (oldPackets.length != newPackets.length) {
    throw const FormatException('Ogg packet count changed during rewrite');
  }
  for (var i = 0; i < oldPackets.length; i++) {
    final old = oldPackets[i];
    final rewritten = newPackets[i];
    final oldComment = _hasPrefix(old, 0, [0x03, ...'vorbis'.codeUnits]);
    final newComment = _hasPrefix(rewritten, 0, [0x03, ...'vorbis'.codeUnits]);
    if (oldComment != newComment ||
        (!oldComment && !_bytesEqual(old, rewritten))) {
      throw const FormatException('Ogg non-comment packet was not preserved');
    }
  }
}

List<Uint8List> _packetsForPages(Uint8List bytes, List<_Page> pages) {
  final result = <Uint8List>[];
  for (final page in pages) {
    var cursor = page.payloadStart;
    var start = cursor;
    for (final lace in page.laces) {
      cursor += lace;
      if (lace < 255) {
        result.add(bytes.sublist(start, cursor));
        start = cursor;
      }
    }
  }
  return result;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

Set<String> _readKeys(Uint8List packet) {
  const marker = 7;
  final view = ByteData.sublistView(packet);
  if (packet.length < marker + 8) {
    throw const FormatException('Malformed Vorbis comment packet');
  }
  final vendor = view.getUint32(marker, Endian.little);
  if (vendor > _maxVendorBytes || marker + 4 + vendor > packet.length) {
    throw const FormatException('Malformed Vorbis vendor');
  }
  _decodeUtf8(packet.sublist(marker + 4, marker + 4 + vendor), 'Vorbis vendor');
  var offset = marker + 4 + vendor;
  if (offset + 4 > packet.length) {
    throw const FormatException('Malformed Vorbis comment packet');
  }
  final count = view.getUint32(offset, Endian.little);
  offset += 4;
  if (count > _maxComments) {
    throw const FormatException('Vorbis comment count exceeds cap');
  }
  final keys = <String>{};
  for (var i = 0; i < count; i++) {
    if (offset + 4 > packet.length) {
      throw const FormatException('Malformed Vorbis comment packet');
    }
    final length = view.getUint32(offset, Endian.little);
    offset += 4;
    if (length > _maxEntryBytes || length > packet.length - offset) {
      throw const FormatException('Malformed Vorbis comment packet');
    }
    final entry = packet.sublist(offset, offset + length);
    offset += length;
    final equals = entry.indexOf(0x3d);
    if (equals <= 0) {
      throw const FormatException('Malformed Vorbis comment packet');
    }
    final decoded = _decodeUtf8(entry, 'Vorbis comment entry');
    keys.add(_normalize(decoded.substring(0, decoded.indexOf('='))));
  }
  if (offset != packet.length) {
    throw const FormatException('Malformed Vorbis comment packet');
  }
  return keys;
}

String _normalize(String key) {
  try {
    return MetadataFieldId.normalizeVorbisCommentKey(key);
  } on ArgumentError {
    throw const FormatException('Invalid Vorbis comment key');
  }
}

String _decodeUtf8(List<int> bytes, String label) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    throw FormatException('$label is not valid UTF-8');
  }
}

List<int> _lace(int length) {
  if (length == 0) {
    return [0];
  }
  final result = <int>[];
  var remaining = length;
  while (remaining > 255) {
    result.add(255);
    remaining -= 255;
  }
  result.add(remaining);
  if (result.last == 255) {
    result.add(0);
  }
  return result;
}

int _le32At(Uint8List bytes, int offset) =>
    bytes[offset] |
    bytes[offset + 1] << 8 |
    bytes[offset + 2] << 16 |
    bytes[offset + 3] << 24;
List<int> _le32(int value) =>
    [value & 255, value >> 8 & 255, value >> 16 & 255, value >> 24 & 255];
bool _hasPrefix(Uint8List bytes, int offset, List<int> prefix) =>
    offset + prefix.length <= bytes.length &&
    prefix.asMap().entries.every((e) => bytes[offset + e.key] == e.value);
int _crc(Uint8List page) {
  var crc = 0;
  for (var i = 0; i < page.length; i++) {
    if (i >= 22 && i < 26) {
      continue;
    }
    crc ^= page[i] << 24;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 0x80000000) != 0
          ? (crc << 1 ^ 0x04C11DB7) & 0xFFFFFFFF
          : (crc << 1) & 0xFFFFFFFF;
    }
  }
  return crc;
}
