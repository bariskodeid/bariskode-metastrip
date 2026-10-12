#!/usr/bin/env python3
"""Materialize the Z01-Z10 ZIP-family stress fixtures for device runs.

The host test suite
(``test/features/remover/data/datasources/zip_family_memory_stress_test.dart``)
builds equivalent archives in memory, so nothing large is committed to the
repository. This script writes the same fixture family to disk for the manual
device lanes described in ``docs/DEVICE_AND_STRESS_TEST_PLAN.md`` section 4,
and prints a fixture manifest (SHA-256 + size per fixture) using the template
from that document.

Run it on a machine with spare disk space; the full set needs roughly 400 MB.

Examples::

    python scripts/generate_device_fixtures.py --help
    python scripts/generate_device_fixtures.py --dry-run --skip-large
    python scripts/generate_device_fixtures.py --out ./fixtures --only Z01,Z03
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import os
import re
import struct
import subprocess
import sys
import tempfile
import zlib
from dataclasses import dataclass
from typing import Callable, Iterable, Sequence

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIP_REPACK_DART = os.path.join(
    REPO_ROOT, "lib", "core", "processing", "zip_repack.dart"
)

DEFAULT_MAX_REPACK_TOTAL_SIZE = 32 * 1024 * 1024
DEFAULT_MAX_REPACK_ENTRY_COUNT = 2000

LARGE_FIXTURE_THRESHOLD = 1024 * 1024

DOCX_CONTENT_TYPES = (
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
    'content-types">'
    '<Override PartName="/word/document.xml" '
    'ContentType="application/vnd.openxmlformats-officedocument.'
    'wordprocessingml.document.main+xml"/>'
    "</Types>"
)

CORE_XML = (
    "<cp:coreProperties "
    'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/'
    'core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/">'
    "<dc:creator>Jane</dc:creator>"
    "</cp:coreProperties>"
)

META_XML = (
    "<office:document-meta "
    'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0">'
    "<office:meta><meta:generator>MetaStrip</meta:generator></office:meta>"
    "</office:document-meta>"
)

ODT_MIMETYPE = "application/vnd.oasis.opendocument.text"

LOCAL_SIGNATURE = 0x04034B50
CENTRAL_SIGNATURE = 0x02014B50
EOCD_SIGNATURE = 0x06054B50


def _read_dart_int(name: str, fallback: int) -> int:
    """Reads ``const int <name> = <expr>;`` from the ZIP repack source."""
    try:
        with open(ZIP_REPACK_DART, "r", encoding="utf-8") as handle:
            source = handle.read()
    except OSError:
        return fallback
    match = re.search(rf"const int {name}\s*=\s*([0-9*\s]+);", source)
    if not match:
        return fallback
    expression = match.group(1).strip()
    if not re.fullmatch(r"[0-9*\s]+", expression):
        return fallback
    value = 1
    for factor in expression.split("*"):
        value *= int(factor.strip())
    return value


MAX_REPACK_TOTAL_SIZE = _read_dart_int(
    "maxRepackTotalSize", DEFAULT_MAX_REPACK_TOTAL_SIZE
)
MAX_REPACK_ENTRY_COUNT = _read_dart_int(
    "maxRepackEntryCount", DEFAULT_MAX_REPACK_ENTRY_COUNT
)


@dataclass
class Entry:
    """One zip record whose headers can deliberately disagree with content."""

    name: str
    data: bytes
    uncompressed_size: int
    crc: int
    method: int = 0
    flags: int = 0
    central_uncompressed_size: int | None = None
    central_crc: int | None = None


def stored(name: str, content: bytes) -> Entry:
    return Entry(
        name=name,
        data=content,
        uncompressed_size=len(content),
        crc=zlib.crc32(content) & 0xFFFFFFFF,
        method=0,
    )


def deflated(
    name: str,
    content: bytes,
    declared_uncompressed_size: int | None = None,
) -> Entry:
    compressor = zlib.compressobj(9, zlib.DEFLATED, -zlib.MAX_WBITS)
    data = compressor.compress(content) + compressor.flush()
    return Entry(
        name=name,
        data=data,
        uncompressed_size=(
            len(content)
            if declared_uncompressed_size is None
            else declared_uncompressed_size
        ),
        crc=zlib.crc32(content) & 0xFFFFFFFF,
        method=8,
    )


def build_zip(
    entries: Sequence[Entry],
    disk_number: int = 0,
    directory_disk: int = 0,
    zip64: bool = False,
) -> bytes:
    """Writes a zip byte-for-byte so malformed headers stay malformed."""
    local = bytearray()
    offsets: list[int] = []
    for entry in entries:
        offsets.append(len(local))
        name = entry.name.encode("utf-8")
        local += struct.pack(
            "<IHHHHHIIIHH",
            LOCAL_SIGNATURE,
            20,
            entry.flags,
            entry.method,
            0,
            0x21,
            entry.crc,
            len(entry.data),
            entry.uncompressed_size,
            len(name),
            0,
        )
        local += name
        local += entry.data

    central = bytearray()
    for index, entry in enumerate(entries):
        name = entry.name.encode("utf-8")
        central += struct.pack(
            "<IHHHHHHIIIHHHHHII",
            CENTRAL_SIGNATURE,
            20,
            20,
            entry.flags,
            entry.method,
            0,
            0x21,
            entry.crc if entry.central_crc is None else entry.central_crc,
            len(entry.data),
            (
                entry.uncompressed_size
                if entry.central_uncompressed_size is None
                else entry.central_uncompressed_size
            ),
            len(name),
            0,
            0,
            0,
            0,
            0,
            offsets[index],
        )
        central += name

    count = 0xFFFF if zip64 else len(entries)
    end = struct.pack(
        "<IHHHHIIH",
        EOCD_SIGNATURE,
        disk_number,
        directory_disk,
        count,
        count,
        0xFFFFFFFF if zip64 else len(central),
        0xFFFFFFFF if zip64 else len(local),
        0,
    )
    return bytes(local) + bytes(central) + end


def padded_archive(
    aggregate: int,
    fixed_entries: dict[str, bytes],
    payload_path: str,
) -> bytes:
    """Builds an archive whose declared aggregate size equals [aggregate]."""
    fixed = sum(len(value) for value in fixed_entries.values())
    payload = b"\0" * (aggregate - fixed)
    entries = [stored(name, value) for name, value in fixed_entries.items()]
    entries.append(stored(payload_path, payload))
    return build_zip(entries)


def docx_bytes(aggregate: int) -> bytes:
    return padded_archive(
        aggregate,
        {
            "[Content_Types].xml": DOCX_CONTENT_TYPES.encode("utf-8"),
            "word/document.xml": b"<w:document/>",
            "docProps/core.xml": CORE_XML.encode("utf-8"),
        },
        "word/media/payload.bin",
    )


def odt_bytes(aggregate: int) -> bytes:
    return padded_archive(
        aggregate,
        {
            "mimetype": ODT_MIMETYPE.encode("utf-8"),
            "content.xml": b"<office:document-content/>",
            "meta.xml": META_XML.encode("utf-8"),
        },
        "Pictures/payload.bin",
    )


def zip_bytes(aggregate: int) -> bytes:
    return padded_archive(aggregate, {"notes.txt": b"hello"}, "payload.bin")


def raw_docx(payload: Iterable[Entry]) -> bytes:
    return build_zip(
        [
            stored("[Content_Types].xml", DOCX_CONTENT_TYPES.encode("utf-8")),
            stored("word/document.xml", b"<w:document/>"),
            stored("docProps/core.xml", CORE_XML.encode("utf-8")),
            *payload,
        ]
    )


#: Declared uncompressed bytes contributed by the fixed [raw_docx] parts.
RAW_DOCX_FIXED_SIZE = (
    len(DOCX_CONTENT_TYPES.encode("utf-8"))
    + len(b"<w:document/>")
    + len(CORE_XML.encode("utf-8"))
)


def many_entry_zip(count: int) -> bytes:
    return build_zip(
        [stored(f"entry_{index:05d}.txt", b"x") for index in range(count)]
    )


def _with(entry: Entry, **overrides: int) -> Entry:
    for key, value in overrides.items():
        setattr(entry, key, value)
    return entry


@dataclass
class Fixture:
    """One manifest row plus the callable that produces its bytes."""

    name: str
    scenario: str
    extensions: tuple[str, ...]
    build: Callable[[], bytes]


def fixtures() -> list[Fixture]:
    """Returns the Z01-Z10 fixture set in matrix order."""
    cap = MAX_REPACK_TOTAL_SIZE
    guard = MAX_REPACK_ENTRY_COUNT
    result: list[Fixture] = []

    for label, aggregate, offset in (
        ("Z01", cap - 1, "32 MiB minus 1 byte"),
        ("Z02", cap, "exactly 32 MiB"),
        ("Z03", cap + 1, "32 MiB plus 1 byte"),
    ):
        result += [
            Fixture(
                f"{label.lower()}_openxml_{aggregate}.docx",
                f"{label} aggregate {offset}",
                ("docx",),
                lambda aggregate=aggregate: docx_bytes(aggregate),
            ),
            Fixture(
                f"{label.lower()}_odf_{aggregate}.odt",
                f"{label} aggregate {offset}",
                ("odt",),
                lambda aggregate=aggregate: odt_bytes(aggregate),
            ),
            Fixture(
                f"{label.lower()}_zip_{aggregate}.zip",
                f"{label} aggregate {offset}",
                ("zip",),
                lambda aggregate=aggregate: zip_bytes(aggregate),
            ),
        ]

    result += [
        Fixture(
            "z04_central_local_size_mismatch.docx",
            "Z04 central size disagrees with local header",
            ("docx",),
            lambda: raw_docx(
                [
                    _with(
                        stored("word/media/payload.bin", b"\0" * 4096),
                        central_uncompressed_size=cap,
                    )
                ]
            ),
        ),
        Fixture(
            "z04_overstated_above_cap.docx",
            "Z04 overstated declared size above the cap",
            ("docx",),
            lambda: raw_docx(
                [
                    deflated(
                        "word/media/payload.bin",
                        b"\0" * 4096,
                        declared_uncompressed_size=cap + 1,
                    )
                ]
            ),
        ),
        Fixture(
            "z04_understated_below_actual.docx",
            "Z04 understated declared size with oversized real content",
            ("docx",),
            lambda: raw_docx(
                [
                    deflated(
                        "word/media/payload.bin",
                        b"\0" * (cap + 1024 * 1024),
                        declared_uncompressed_size=1024,
                    )
                ]
            ),
        ),
        Fixture(
            "z05_ratio_below_cap.docx",
            "Z05 high ratio expanding below the cap",
            ("docx",),
            lambda: raw_docx(
                [deflated("word/media/payload.bin", b"\0" * (1024 * 1024))]
            ),
        ),
        Fixture(
            "z05_ratio_at_cap.docx",
            "Z05 high ratio expanding to exactly the aggregate cap",
            ("docx",),
            lambda: raw_docx(
                [
                    deflated(
                        "word/media/payload.bin",
                        b"\0" * (cap - RAW_DOCX_FIXED_SIZE),
                    )
                ]
            ),
        ),
        Fixture(
            "z05_ratio_above_cap.docx",
            "Z05 high ratio expanding above the aggregate cap",
            ("docx",),
            lambda: raw_docx(
                [
                    deflated(
                        "word/media/payload.bin",
                        b"\0" * (cap - RAW_DOCX_FIXED_SIZE + 1),
                    )
                ]
            ),
        ),
        Fixture(
            f"z06_entries_{guard - 1}.zip",
            f"Z06 entry count below the {guard} entry guard",
            ("zip",),
            lambda: many_entry_zip(guard - 1),
        ),
        Fixture(
            f"z06_entries_{guard}.zip",
            f"Z06 entry count at the {guard} entry guard",
            ("zip",),
            lambda: many_entry_zip(guard),
        ),
        Fixture(
            f"z06_entries_{guard + 1}.zip",
            f"Z06 entry count above the {guard} entry guard",
            ("zip",),
            lambda: many_entry_zip(guard + 1),
        ),
        Fixture(
            "z07_batch_member.docx",
            "Z07 sequential batch member (repeat with Z01/Z02 fixtures)",
            ("docx",),
            lambda: docx_bytes(cap),
        ),
        Fixture(
            "z08_cancellation_target.odt",
            "Z08 cancellation target at the boundary",
            ("odt",),
            lambda: odt_bytes(cap),
        ),
        Fixture(
            "z09_low_memory_target.docx",
            "Z09 low-memory pressure target at the boundary",
            ("docx",),
            lambda: docx_bytes(cap),
        ),
        Fixture(
            "z10_zip64_sentinels.zip",
            "Z10 ZIP64 sentinel end record",
            ("zip",),
            lambda: build_zip([stored("a.txt", b"payload")], zip64=True),
        ),
        Fixture(
            "z10_multi_disk.zip",
            "Z10 multi-disk end record",
            ("zip",),
            lambda: build_zip(
                [stored("a.txt", b"payload")],
                disk_number=1,
                directory_disk=1,
            ),
        ),
        Fixture(
            "z10_encrypted_flag.zip",
            "Z10 encrypted entry flag",
            ("zip",),
            lambda: build_zip([_with(stored("a.txt", b"payload"), flags=0x1)]),
        ),
        Fixture(
            "z10_duplicate_path.zip",
            "Z10 duplicate normalized path",
            ("zip",),
            lambda: build_zip(
                [stored("a/b.txt", b"one"), stored("a//b.txt", b"two")]
            ),
        ),
        Fixture(
            "z10_unsupported_method.zip",
            "Z10 unsupported compression method",
            ("zip",),
            lambda: build_zip([_with(stored("a.txt", b"payload"), method=12)]),
        ),
        Fixture(
            "z10_central_crc_mismatch.zip",
            "Z10 central CRC disagrees with the local header",
            ("zip",),
            lambda: build_zip(
                [_with(stored("a.txt", b"payload"), central_crc=0x0DEADBEE)]
            ),
        ),
        Fixture(
            "z10_path_traversal.zip",
            "Z10 path traversal entry",
            ("zip",),
            lambda: build_zip([stored("../escape.txt", b"payload")]),
        ),
    ]
    return result


def git_commit() -> str:
    try:
        output = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return "<unknown>"
    return output.stdout.strip()


def selected_fixtures(
    only: Sequence[str], skip_large: bool
) -> list[Fixture]:
    chosen = fixtures()
    if only:
        wanted = {value.strip().upper() for value in only}
        chosen = [
            fixture
            for fixture in chosen
            if fixture.scenario.split(" ", 1)[0].upper() in wanted
        ]
    if skip_large:
        chosen = [
            fixture
            for fixture in chosen
            if not fixture.name.startswith(("z01", "z02", "z03", "z07", "z09"))
            and "cancellation" not in fixture.name
        ]
    return chosen


def render_manifest(rows: list[dict[str, object]], out_dir: str) -> str:
    generated = _dt.datetime.now(_dt.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    lines = [
        "fixture_manifest_version: 1",
        f"generated_at: {generated}",
        "generator: scripts/generate_device_fixtures.py",
        f"git_commit: {git_commit()}",
        f"output_directory: {out_dir}",
        f"boundary_bytes: {MAX_REPACK_TOTAL_SIZE}",
        f"entry_count_guard: {MAX_REPACK_ENTRY_COUNT}",
        "fixtures:",
    ]
    for row in rows:
        lines += [
            f"  - name: {row['name']}",
            f"    path: {row['path']}",
            f"    sha256: {row['sha256']}",
            f"    size_bytes: {row['size_bytes']}",
            "    extensions:",
        ]
        for extension in row["extensions"]:  # type: ignore[union-attr]
            lines.append(f"      - {extension}")
        lines.append(f"    scenario: {row['scenario']}")
    body = "\n".join(lines) + "\n"
    digest = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return body + f"manifest_sha256: {digest}\n"


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Generate the Z01-Z10 ZIP-family stress fixtures for manual "
            "device runs and print their fixture manifest."
        )
    )
    parser.add_argument(
        "--out",
        default=None,
        help=(
            "Output directory (created if missing). Defaults to a new "
            "temporary directory."
        ),
    )
    parser.add_argument(
        "--only",
        default="",
        help="Comma-separated matrix IDs to generate, e.g. 'Z01,Z10'.",
    )
    parser.add_argument(
        "--skip-large",
        action="store_true",
        help="Skip the boundary-sized fixtures (~32 MiB each).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build fixtures in memory and print the manifest without "
        "writing any file.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List the fixture names and scenarios, then exit.",
    )
    args = parser.parse_args(argv)

    only = [value for value in args.only.split(",") if value.strip()]
    chosen = selected_fixtures(only, args.skip_large)
    if not chosen:
        print("No fixtures matched the selection.", file=sys.stderr)
        return 1

    if args.list:
        for fixture in chosen:
            print(f"{fixture.name}\t{fixture.scenario}")
        return 0

    out_dir = args.out or tempfile.mkdtemp(prefix="metastrip_zip_fixtures_")
    if not args.dry_run:
        os.makedirs(out_dir, exist_ok=True)

    rows: list[dict[str, object]] = []
    for fixture in chosen:
        data = fixture.build()
        digest = hashlib.sha256(data).hexdigest()
        path = os.path.join(out_dir, fixture.name)
        if not args.dry_run:
            with open(path, "wb") as handle:
                handle.write(data)
        rows.append(
            {
                "name": fixture.name,
                "path": path,
                "sha256": digest,
                "size_bytes": len(data),
                "extensions": fixture.extensions,
                "scenario": fixture.scenario,
            }
        )
        marker = " (large)" if len(data) > LARGE_FIXTURE_THRESHOLD else ""
        print(
            f"{fixture.name}  {len(data)} bytes  sha256={digest}{marker}",
            file=sys.stderr,
        )

    manifest = render_manifest(rows, out_dir)
    if not args.dry_run:
        manifest_path = os.path.join(out_dir, "fixture_manifest.yaml")
        with open(manifest_path, "w", encoding="utf-8") as handle:
            handle.write(manifest)
        print(f"manifest written to {manifest_path}", file=sys.stderr)
    print(manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
