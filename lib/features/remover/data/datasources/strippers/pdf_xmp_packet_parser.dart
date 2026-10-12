/// Maximum number of XMP packets processed in one scrub or generated-byte
/// validation pass.
const maxPdfXmpPacketOccurrences = 64;

/// The literal marker that opens every `xpacket` processing instruction.
const pdfXmpPacketMarker = '<?xpacket';

/// Half-open byte range occupied by an XMP packet's mutable content.
///
/// The range covers only the bytes between the begin instruction's closing
/// `?>` and the `<` of the matching `<?xpacket end` instruction, so both
/// instructions survive a same-length blanking pass.
final class PdfXmpPacketRange {
  const PdfXmpPacketRange(this.start, this.end, this.nextSearchOffset);

  final int start;
  final int end;
  final int nextSearchOffset;
}

/// Finds the mutable content ranges of every literal XMP packet in [text].
///
/// The scan is a single forward pass of plain `String.indexOf` searches over
/// the latin-1 decoded payload, mirroring how the viewer detects XMP. Packets
/// stored inside compressed object streams are not visible as literal text and
/// are therefore not reported.
///
/// Fails closed with a [FormatException] on any unbalanced, nested, truncated,
/// or unrecognized `xpacket` instruction, and on more than
/// [maxPdfXmpPacketOccurrences] packets.
List<PdfXmpPacketRange> findPdfXmpPacketRanges(String text) {
  final ranges = <PdfXmpPacketRange>[];
  var searchFrom = 0;
  while (true) {
    final begin = text.indexOf(pdfXmpPacketMarker, searchFrom);
    if (begin < 0) break;
    if (ranges.length >= maxPdfXmpPacketOccurrences) {
      throw const FormatException('Too many XMP packet occurrences');
    }
    final beginClose = _instructionEnd(text, begin);
    if (_instructionKind(text, begin, beginClose) != _XmpInstruction.begin) {
      throw const FormatException('Unbalanced XMP packet instruction');
    }
    final contentStart = beginClose + 2;

    final end = text.indexOf(pdfXmpPacketMarker, contentStart);
    if (end < 0) {
      throw const FormatException('Unterminated XMP packet');
    }
    final endClose = _instructionEnd(text, end);
    if (_instructionKind(text, end, endClose) != _XmpInstruction.end) {
      throw const FormatException('Unbalanced XMP packet instruction');
    }

    ranges.add(PdfXmpPacketRange(contentStart, end, endClose + 2));
    searchFrom = endClose + 2;
  }
  return ranges;
}

enum _XmpInstruction { begin, end }

/// Returns the index of the `?>` that closes the instruction at [start].
int _instructionEnd(String text, int start) {
  final close = text.indexOf('?>', start + pdfXmpPacketMarker.length);
  if (close < 0) {
    throw const FormatException('Unterminated XMP packet instruction');
  }
  return close;
}

/// Classifies the `xpacket` instruction spanning `[start, close)`.
_XmpInstruction _instructionKind(String text, int start, int close) {
  final body = text.substring(start + pdfXmpPacketMarker.length, close).trim();
  if (body.startsWith('begin')) return _XmpInstruction.begin;
  if (body.startsWith('end')) return _XmpInstruction.end;
  throw const FormatException('Unrecognized XMP packet instruction');
}
