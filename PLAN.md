# torinfo.cr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crystal shard + CLI that parses BitTorrent v1/v2/hybrid `.torrent` files, exposes a typed API, and renders metadata as text, JSON, bashvars, or bashfunc output.

**Architecture:** `BencodeParser` → `Torrent` class (v1/v2/hybrid) → four formatter classes → hand-rolled `CLI` class. The library (`src/torinfo.cr`) is usable independently of the CLI.

**Tech Stack:** Crystal 1.20+, Spectator 0.11 (testing), Guard (nil safety), `Digest::SHA1` + `Digest::SHA256` (stdlib, for info hashes).

---

## File Structure

```
src/
  torinfo.cr                        # Library entry: requires all public types
  torinfo/
    byte_string.cr                  # ByteString: wraps Bytes, provides .hex / .base64
    bencode.cr                      # BencodeParser + BencodeValue alias; tracks info dict byte range
    torrent_file.cr                 # TorrentFile struct: path (joined), size, pieces_root
    torrent.cr                      # Torrent class: parses .torrent, exposes all fields (v1/v2/hybrid)
    formatters/
      text.cr                       # TextFormatter
      json.cr                       # JsonFormatter (NDJSON for multiple files)
      bash_vars.cr                  # BashVarsFormatter (--bashv)
      bash_func.cr                  # BashFuncFormatter (--bashf)
    cli.cr                          # CLI class: hand-rolled arg parser + run method
  torinfo_cli.cr                    # Entrypoint: require cli; Torinfo::CLI.new.run

spec/
  spec_helper.cr                    # require "spectator" + torinfo
  support/
    fixture_builder.cr              # Bencode encoder + known fixture bytes (used by generator + tests)
  fixtures/
    generate.cr                     # Generates fixture .torrent files from fixture_builder
    v1_single.torrent
    v1_multi.torrent
    v2_single.torrent
    hybrid.torrent
  torinfo/
    byte_string_spec.cr
    bencode_spec.cr
    torrent_spec.cr
    formatters/
      text_spec.cr
      json_spec.cr
      bash_vars_spec.cr
      bash_func_spec.cr
    cli_spec.cr

shard.yml
.ameba.yml
Makefile
```

---

## Design Reference

### `BencodeValue` type alias
```crystal
alias BencodeValue = Bytes | Int64 | Array(BencodeValue) | Hash(String, BencodeValue)
```
All bencode byte strings are `Bytes` (including names, URLs, pieces blob). `Torrent` converts known-UTF-8 fields to `String`.

### `format_version` integer
- `1` = v1 only (`pieces` present, no `meta version` key)
- `2` = v2 only (`meta version: 2`, no `pieces`)
- `3` = hybrid (both present)

### Info hash computation
- v1: `Digest::SHA1.digest(info_raw_bytes)` → 20-byte `ByteString`
- v2: `Digest::SHA256.digest(info_raw_bytes)` → 32-byte `ByteString`
- `BencodeParser` tracks the byte range of the `info` value during top-level dict parsing.

### `Torrent` public API (unified across versions)
| Getter | Type | Notes |
|---|---|---|
| `path` | `String` | Path of the `.torrent` file |
| `name` | `String` | Torrent name |
| `format_version` | `Int32` | 1, 2, or 3 |
| `info_hash_v1` | `ByteString?` | nil for v2-only |
| `info_hash_v2` | `ByteString?` | nil for v1-only |
| `hash` | `String` | `"v1 <hex>"` (v1 preferred) or `"v2 <hex>"` |
| `created_by` | `String?` | |
| `created_on` | `Time?` | |
| `comment` | `String?` | |
| `source` | `String?` | |
| `piece_size` | `Int64` | bytes per piece |
| `piece_count` | `Int64` | |
| `total_size` | `Int64` | sum of all file sizes |
| `private?` | `Bool` | |
| `visibility` | `String` | `"private"` or `"public"` |
| `trackers` | `Array(String)` | deduped; announce + announce-list flattened |
| `files` | `Array(TorrentFile)` | always ≥ 1 entry |

### `TorrentFile` struct
| Field | Type | Notes |
|---|---|---|
| `path` | `String` | joined (e.g., `Movies/file.mkv`); for v2, as stored in file tree |
| `size` | `Int64` | |
| `pieces_root` | `ByteString?` | v2 per-file merkle root; nil for v1 |

### `--bashv` variables (PREFIX_ always exported)
Scalars: `path`, `name`, `hash`, `created_by`, `created_on`, `comment`, `source`, `piece_count`, `piece_size`, `total_size`, `visibility`, `format_version`
Arrays: `trackers`, `filename`, `filesize`, `variables`

- `PREFIX_path` = path to the `.torrent` file
- `PREFIX_filename=(...)` = array of torrent content file paths
- `PREFIX_filesize=(...)` = array of torrent content file sizes
- `PREFIX_variables=(...)` = names of every variable emitted (including `PREFIX_variables` itself), so `unset "${PREFIX_variables[@]}"` clears them all

**Prefix expansion with multiple files:**
- Prefix contains `%d`-style format (matched by `/\A.*%0*\d*d.*\z/`): use `sprintf(prefix, n)` per file (1-based)
- No format pattern + multiple files: append `_1`, `_2`, … to prefix
- Single file: use prefix as-is

### `--bashf` argument order
`path name hash created_by created_on comment source piece_count piece_size total_size visibility format_version [trackers...] -- [file_path file_size ...]`

### TTY vs non-TTY (both formatters)
- Non-TTY (`STDOUT.tty?` false): compact single line per file, no `\` continuations
- TTY: pretty-printed with `\` continuations, blank line between files

### Timestamp formatting
- Default: `time.to_rfc3339`
- `--strftime FORMAT`: `time.to_s(FORMAT)`
- `--unix-epoch`: `time.to_unix.to_s` (convenience; treated as special case, not a strftime pattern)

### Quoting in bash output
- String values: single-quoted; internal `'` escaped as `'\''`
- Integer values (`piece_count`, `piece_size`, `total_size`, `format_version`): unquoted
- `visibility`: unquoted
- Array elements: single-quoted

### Error cases
- `--bashv` or `--bashf` combined with any field specifier (`--name`, `--hash`, etc.): print error to stderr, exit 1
- Unknown `--flag`: print error to stderr, exit 1
- Missing argument to option that requires one: print error to stderr, exit 1

---

## Task 1: Project Setup

**Files:**
- Modify: `shard.yml`
- Create: `.ameba.yml`
- Create: `Makefile`
- Modify: `spec/spec_helper.cr`

- [ ] **Step 1: Update shard.yml**

```yaml
name: torinfo
version: 0.1.0

authors:
  - Paul M. Lambert <plambert@plambert.net>

description: Crystal shard and CLI for reading BitTorrent .torrent files

crystal: ">= 1.20.0"

license: MIT

targets:
  torinfo:
    main: src/torinfo_cli.cr

dependencies:
  guard:
    github: plambert/guard.cr

development_dependencies:
  spectator:
    gitlab: arctic-fox/spectator
    version: "~> 0.11"
  ameba:
    github: crystal-ameba/ameba
    version: "~> 1.6"
```

- [ ] **Step 2: Create .ameba.yml**

```yaml
Metrics/CyclomaticComplexity:
  MaxComplexity: 20
```

- [ ] **Step 3: Create Makefile**

```makefile
PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin

.PHONY: build install test format lint clean

build:
	shards build --error-trace

install: build
	install -d $(BIN_DIR)
	install bin/torinfo $(BIN_DIR)/torinfo

test:
	crystal spec -v --error-trace

format:
	crystal tool format

lint: format
	lib/ameba/bin/ameba src/ spec/

clean:
	rm -rf bin/ lib/
```

- [ ] **Step 4: Update spec/spec_helper.cr**

```crystal
require "spectator"
require "../src/torinfo"
```

- [ ] **Step 5: Run shards install**

```bash
shards install
```

Expected: `lib/` directory created with guard, spectator, ameba.

- [ ] **Step 6: Verify tests compile (they will fail)**

```bash
crystal spec -v --error-trace
```

Expected: compilation error since `src/torinfo.cr` has no real code yet — that is correct.

---

## Task 2: ByteString

**Files:**
- Create: `src/torinfo/byte_string.cr`
- Create: `spec/torinfo/byte_string_spec.cr`

- [ ] **Step 1: Write the failing test**

Create `spec/torinfo/byte_string_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::ByteString do
  let(bytes) { Bytes[0xde, 0xad, 0xbe, 0xef] }
  subject(bs) { Torinfo::ByteString.new(bytes) }

  describe "#bytes" do
    it "returns the wrapped bytes" do
      expect(bs.bytes).to eq(bytes)
    end
  end

  describe "#hex" do
    it "returns lowercase hex string" do
      expect(bs.hex).to eq("deadbeef")
    end

    it "zero-pads single-digit bytes" do
      single = Torinfo::ByteString.new(Bytes[0x0f])
      expect(single.hex).to eq("0f")
    end
  end

  describe "#base64" do
    it "returns strict base64 encoding" do
      expect(bs.base64).to eq("3q2+7w==")
    end
  end

  describe "#to_s" do
    it "renders as hex" do
      expect(bs.to_s).to eq("deadbeef")
    end
  end

  describe "#==" do
    it "equals another ByteString with same bytes" do
      expect(bs).to eq(Torinfo::ByteString.new(Bytes[0xde, 0xad, 0xbe, 0xef]))
    end

    it "does not equal a ByteString with different bytes" do
      expect(bs).not_to eq(Torinfo::ByteString.new(Bytes[0x00]))
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/byte_string_spec.cr -v --error-trace
```

Expected: compilation error — `Torinfo::ByteString` not defined.

- [ ] **Step 3: Implement ByteString**

Create `src/torinfo/byte_string.cr`:

```crystal
require "base64"

module Torinfo
  struct ByteString
    getter bytes : Bytes

    def initialize(@bytes : Bytes)
    end

    def hex : String
      String.build do |io|
        @bytes.each { |byte| io.printf("%02x", byte) }
      end
    end

    def base64 : String
      Base64.strict_encode(@bytes)
    end

    def ==(other : ByteString) : Bool
      @bytes == other.bytes
    end

    def to_s(io : IO) : Nil
      io << hex
    end
  end
end
```

Update `src/torinfo.cr`:

```crystal
require "./torinfo/byte_string"

module Torinfo
  VERSION = "0.1.0"
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/byte_string_spec.cr -v --error-trace
```

Expected: all examples pass.

- [ ] **Step 5: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/byte_string.cr
```

- [ ] **Step 6: Commit**

```bash
git add shard.yml shard.lock .ameba.yml Makefile spec/spec_helper.cr src/torinfo.cr src/torinfo/byte_string.cr spec/torinfo/byte_string_spec.cr
git commit -m "feat: project setup, shard dependencies, ByteString type"
```

---

## Task 3: BencodeParser

**Files:**
- Create: `src/torinfo/bencode.cr`
- Create: `spec/torinfo/bencode_spec.cr`

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/bencode_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::BencodeParser do
  describe ".parse" do
    context "integers" do
      it "parses a positive integer" do
        result = Torinfo::BencodeParser.parse("i42e".to_slice)
        expect(result).to be_a(Int64)
        expect(result.as(Int64)).to eq(42_i64)
      end

      it "parses a negative integer" do
        result = Torinfo::BencodeParser.parse("i-7e".to_slice)
        expect(result.as(Int64)).to eq(-7_i64)
      end

      it "parses zero" do
        result = Torinfo::BencodeParser.parse("i0e".to_slice)
        expect(result.as(Int64)).to eq(0_i64)
      end
    end

    context "byte strings" do
      it "parses a byte string" do
        result = Torinfo::BencodeParser.parse("4:spam".to_slice)
        expect(result).to be_a(Bytes)
        expect(String.new(result.as(Bytes))).to eq("spam")
      end

      it "parses an empty byte string" do
        result = Torinfo::BencodeParser.parse("0:".to_slice)
        expect(result.as(Bytes).size).to eq(0)
      end

      it "parses binary data (non-UTF-8)" do
        raw = "3:\xde\xad\xbe".to_slice
        result = Torinfo::BencodeParser.parse(raw)
        expect(result.as(Bytes)).to eq(Bytes[0xde, 0xad, 0xbe])
      end
    end

    context "lists" do
      it "parses an empty list" do
        result = Torinfo::BencodeParser.parse("le".to_slice)
        expect(result).to be_a(Array(Torinfo::BencodeValue))
        expect(result.as(Array(Torinfo::BencodeValue)).size).to eq(0)
      end

      it "parses a list of integers" do
        result = Torinfo::BencodeParser.parse("li1ei2ei3ee".to_slice)
        list = result.as(Array(Torinfo::BencodeValue))
        expect(list.size).to eq(3)
        expect(list[0].as(Int64)).to eq(1_i64)
        expect(list[2].as(Int64)).to eq(3_i64)
      end

      it "parses a list of strings" do
        result = Torinfo::BencodeParser.parse("l4:spam4:eggse".to_slice)
        list = result.as(Array(Torinfo::BencodeValue))
        expect(String.new(list[0].as(Bytes))).to eq("spam")
        expect(String.new(list[1].as(Bytes))).to eq("eggs")
      end

      it "parses a nested list" do
        result = Torinfo::BencodeParser.parse("lli1eeli2eee".to_slice)
        outer = result.as(Array(Torinfo::BencodeValue))
        expect(outer.size).to eq(2)
        inner = outer[0].as(Array(Torinfo::BencodeValue))
        expect(inner[0].as(Int64)).to eq(1_i64)
      end
    end

    context "dictionaries" do
      it "parses an empty dict" do
        result = Torinfo::BencodeParser.parse("de".to_slice)
        expect(result).to be_a(Hash(String, Torinfo::BencodeValue))
        expect(result.as(Hash(String, Torinfo::BencodeValue)).size).to eq(0)
      end

      it "parses a simple dict" do
        result = Torinfo::BencodeParser.parse("d3:cow3:moo4:spam4:eggse".to_slice)
        dict = result.as(Hash(String, Torinfo::BencodeValue))
        expect(String.new(dict["cow"].as(Bytes))).to eq("moo")
        expect(String.new(dict["spam"].as(Bytes))).to eq("eggs")
      end

      it "parses a nested dict" do
        result = Torinfo::BencodeParser.parse("d4:infod4:name4:testee".to_slice)
        outer = result.as(Hash(String, Torinfo::BencodeValue))
        inner = outer["info"].as(Hash(String, Torinfo::BencodeValue))
        expect(String.new(inner["name"].as(Bytes))).to eq("test")
      end
    end

    context "errors" do
      it "raises on unknown type byte" do
        expect { Torinfo::BencodeParser.parse("x".to_slice) }.to raise_error(ArgumentError, /invalid/i)
      end

      it "raises on unterminated integer" do
        expect { Torinfo::BencodeParser.parse("i42".to_slice) }.to raise_error(ArgumentError)
      end

      it "raises on truncated string" do
        expect { Torinfo::BencodeParser.parse("5:hi".to_slice) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#info_raw_bytes" do
    it "returns nil when no info key present" do
      parser = Torinfo::BencodeParser.new("d3:foo3:bare".to_slice)
      parser.parse
      expect(parser.info_raw_bytes).to be_nil
    end

    it "returns raw bytes of the info value" do
      # d + "4:info" + info_value + "3:foo" + "3:bar" + e
      raw = "d4:infod4:name4:teste3:foo3:bare".to_slice
      parser = Torinfo::BencodeParser.new(raw)
      parser.parse
      info_bytes = parser.info_raw_bytes
      expect(info_bytes).not_to be_nil
      # The info value is the dict "d4:name4:teste" — verify it round-trips
      reparsed = Torinfo::BencodeParser.parse(info_bytes.not_nil!)
      dict = reparsed.as(Hash(String, Torinfo::BencodeValue))
      expect(String.new(dict["name"].as(Bytes))).to eq("test")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/bencode_spec.cr -v --error-trace
```

Expected: compilation error — `Torinfo::BencodeParser` not defined.

- [ ] **Step 3: Implement BencodeParser**

Create `src/torinfo/bencode.cr`:

```crystal
module Torinfo
  alias BencodeValue = Bytes | Int64 | Array(BencodeValue) | Hash(String, BencodeValue)

  class BencodeParser
    getter raw : Bytes

    @info_range : Range(Int32, Int32)?
    @depth : Int32 = 0

    def initialize(@raw : Bytes)
    end

    def self.parse(bytes : Bytes) : BencodeValue
      new(bytes).parse
    end

    def parse : BencodeValue
      value, _pos = parse_value(0)
      value
    end

    def info_raw_bytes : Bytes?
      return nil unless range = @info_range
      copy = Bytes.new(range.size)
      @raw[range].copy_to(copy)
      copy
    end

    private def parse_value(pos : Int32) : {BencodeValue, Int32}
      raise ArgumentError.new("empty input at position #{pos}") if pos >= @raw.size
      case @raw[pos].chr
      when 'i'               then parse_int(pos)
      when 'l'               then parse_list(pos)
      when 'd'               then parse_dict(pos)
      when '0'..'9'          then parse_string(pos)
      else raise ArgumentError.new("invalid bencode byte #{@raw[pos]} at position #{pos}")
      end
    end

    private def parse_int(pos : Int32) : {Int64, Int32}
      end_pos = find_byte('e', pos + 1)
      str = String.new(@raw[pos + 1, end_pos - pos - 1])
      {str.to_i64, end_pos + 1}
    end

    private def parse_string(pos : Int32) : {Bytes, Int32}
      colon_pos = find_byte(':', pos)
      len = String.new(@raw[pos, colon_pos - pos]).to_i
      start = colon_pos + 1
      raise ArgumentError.new("string at #{pos} claims length #{len} but only #{@raw.size - start} bytes remain") if start + len > @raw.size
      copy = Bytes.new(len)
      @raw[start, len].copy_to(copy)
      {copy, start + len}
    end

    private def parse_list(pos : Int32) : {Array(BencodeValue), Int32}
      result = [] of BencodeValue
      pos += 1
      while pos < @raw.size && @raw[pos].chr != 'e'
        value, pos = parse_value(pos)
        result << value
      end
      raise ArgumentError.new("unterminated list") if pos >= @raw.size
      {result, pos + 1}
    end

    private def parse_dict(pos : Int32) : {Hash(String, BencodeValue), Int32}
      result = {} of String => BencodeValue
      pos += 1
      @depth += 1
      while pos < @raw.size && @raw[pos].chr != 'e'
        key_bytes, pos = parse_string(pos)
        key = String.new(key_bytes)
        if key == "info" && @depth == 1
          value_start = pos
          value, pos = parse_value(pos)
          @info_range = (value_start...pos)
          result[key] = value
        else
          value, pos = parse_value(pos)
          result[key] = value
        end
      end
      raise ArgumentError.new("unterminated dict") if pos >= @raw.size
      @depth -= 1
      {result, pos + 1}
    end

    private def find_byte(char : Char, from pos : Int32) : Int32
      byte = char.ord.to_u8
      while pos < @raw.size
        return pos if @raw[pos] == byte
        pos += 1
      end
      raise ArgumentError.new("byte '#{char}' not found from position #{pos}")
    end
  end
end
```

Update `src/torinfo.cr`:

```crystal
require "./torinfo/byte_string"
require "./torinfo/bencode"

module Torinfo
  VERSION = "0.1.0"
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/bencode_spec.cr -v --error-trace
```

Expected: all examples pass.

- [ ] **Step 5: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/bencode.cr
```

- [ ] **Step 6: Commit**

```bash
git add src/torinfo/bencode.cr src/torinfo.cr spec/torinfo/bencode_spec.cr
git commit -m "feat: BencodeParser with info dict byte range tracking"
```

---

## Task 4: Fixture Builder and Fixture Files

**Files:**
- Create: `spec/support/fixture_builder.cr`
- Create: `spec/fixtures/generate.cr`
- Create: `spec/fixtures/v1_single.torrent` (generated)
- Create: `spec/fixtures/v1_multi.torrent` (generated)
- Create: `spec/fixtures/v2_single.torrent` (generated)
- Create: `spec/fixtures/hybrid.torrent` (generated)

- [ ] **Step 1: Create fixture_builder.cr**

Create `spec/support/fixture_builder.cr`:

```crystal
require "digest/sha1"
require "digest/sha256"

# Bencode encoding helpers and known fixture definitions.
# Used by both spec/fixtures/generate.cr and tests that need to know
# the exact bytes that were encoded (e.g., to verify info hash values).
module FixtureBuilder
  # Minimal bencode encoder. Keys MUST be passed in lexicographic order.
  module Bencode
    def self.string(io : IO, str : String) : Nil
      io << str.bytesize << ':' << str
    end

    def self.bytes(io : IO, data : Bytes) : Nil
      io << data.size << ':'
      io.write(data)
    end

    def self.int(io : IO, value : Int) : Nil
      io << 'i' << value << 'e'
    end

    def self.list(io : IO, & : IO ->) : Nil
      io << 'l'
      yield io
      io << 'e'
    end

    def self.dict(io : IO, & : IO ->) : Nil
      io << 'd'
      yield io
      io << 'e'
    end
  end

  TRACKER_URL    = "https://tracker.example.com/announce"
  BACKUP_URL     = "https://backup.example.com/announce"
  CREATED_BY     = "torinfo-test"
  CREATION_DATE  = 1704067200_i64  # 2024-01-01 00:00:00 UTC
  COMMENT        = "test torrent"
  SOURCE         = "TEST"
  PIECE_LENGTH   = 262144_i64
  ZERO_SHA1      = Bytes.new(20, 0_u8)
  ZERO_SHA256    = Bytes.new(32, 0_u8)

  def self.v1_single_info_bytes : Bytes
    io = IO::Memory.new
    Bencode.dict(io) do
      # Keys in lexicographic order: length, name, piece length, pieces
      Bencode.string(io, "length")
      Bencode.int(io, 1024_i64)
      Bencode.string(io, "name")
      Bencode.string(io, "test-file.txt")
      Bencode.string(io, "piece length")
      Bencode.int(io, PIECE_LENGTH)
      Bencode.string(io, "pieces")
      Bencode.bytes(io, ZERO_SHA1)
    end
    io.to_slice.dup
  end

  def self.v1_multi_info_bytes : Bytes
    io = IO::Memory.new
    pieces = Bytes.new(20, 0_u8)  # 1 piece for 3500 total bytes with 262144 piece length
    Bencode.dict(io) do
      # Keys: files, name, piece length, pieces, private
      Bencode.string(io, "files")
      Bencode.list(io) do
        Bencode.dict(io) do
          # Keys: length, path
          Bencode.string(io, "length")
          Bencode.int(io, 1000_i64)
          Bencode.string(io, "path")
          Bencode.list(io) do
            Bencode.string(io, "subdir")
            Bencode.string(io, "file1.txt")
          end
        end
        Bencode.dict(io) do
          Bencode.string(io, "length")
          Bencode.int(io, 2000_i64)
          Bencode.string(io, "path")
          Bencode.list(io) do
            Bencode.string(io, "subdir")
            Bencode.string(io, "file2.txt")
          end
        end
        Bencode.dict(io) do
          Bencode.string(io, "length")
          Bencode.int(io, 500_i64)
          Bencode.string(io, "path")
          Bencode.list(io) do
            Bencode.string(io, "other.txt")
          end
        end
      end
      Bencode.string(io, "name")
      Bencode.string(io, "test-dir")
      Bencode.string(io, "piece length")
      Bencode.int(io, PIECE_LENGTH)
      Bencode.string(io, "pieces")
      Bencode.bytes(io, pieces)
      Bencode.string(io, "private")
      Bencode.int(io, 1_i64)
    end
    io.to_slice.dup
  end

  def self.v2_single_info_bytes : Bytes
    io = IO::Memory.new
    Bencode.dict(io) do
      # Keys: file tree, meta version, name, piece length
      Bencode.string(io, "file tree")
      Bencode.dict(io) do
        Bencode.string(io, "test-file-v2.txt")
        Bencode.dict(io) do
          Bencode.string(io, "")  # empty string = file entry sentinel
          Bencode.dict(io) do
            # Keys: length, pieces root
            Bencode.string(io, "length")
            Bencode.int(io, 1024_i64)
            Bencode.string(io, "pieces root")
            Bencode.bytes(io, ZERO_SHA256)
          end
        end
      end
      Bencode.string(io, "meta version")
      Bencode.int(io, 2_i64)
      Bencode.string(io, "name")
      Bencode.string(io, "test-file-v2.txt")
      Bencode.string(io, "piece length")
      Bencode.int(io, PIECE_LENGTH)
    end
    io.to_slice.dup
  end

  def self.hybrid_info_bytes : Bytes
    io = IO::Memory.new
    Bencode.dict(io) do
      # Keys: file tree, length, meta version, name, piece length, pieces
      Bencode.string(io, "file tree")
      Bencode.dict(io) do
        Bencode.string(io, "hybrid-file.txt")
        Bencode.dict(io) do
          Bencode.string(io, "")
          Bencode.dict(io) do
            Bencode.string(io, "length")
            Bencode.int(io, 1024_i64)
            Bencode.string(io, "pieces root")
            Bencode.bytes(io, ZERO_SHA256)
          end
        end
      end
      Bencode.string(io, "length")
      Bencode.int(io, 1024_i64)
      Bencode.string(io, "meta version")
      Bencode.int(io, 2_i64)
      Bencode.string(io, "name")
      Bencode.string(io, "hybrid-file.txt")
      Bencode.string(io, "piece length")
      Bencode.int(io, PIECE_LENGTH)
      Bencode.string(io, "pieces")
      Bencode.bytes(io, ZERO_SHA1)
    end
    io.to_slice.dup
  end

  def self.write_torrent(path : String, info_bytes : Bytes, announce_list : Bool = false) : Nil
    File.open(path, "wb") do |file|
      Bencode.dict(file) do
        # Keys: announce, [announce-list,] comment, created by, creation date, info, source
        Bencode.string(file, "announce")
        Bencode.string(file, TRACKER_URL)
        if announce_list
          Bencode.string(file, "announce-list")
          Bencode.list(file) do
            Bencode.list(file) { Bencode.string(file, TRACKER_URL) }
            Bencode.list(file) { Bencode.string(file, BACKUP_URL) }
          end
        end
        Bencode.string(file, "comment")
        Bencode.string(file, COMMENT)
        Bencode.string(file, "created by")
        Bencode.string(file, CREATED_BY)
        Bencode.string(file, "creation date")
        Bencode.int(file, CREATION_DATE)
        Bencode.string(file, "info")
        file.write(info_bytes)
        Bencode.string(file, "source")
        Bencode.string(file, SOURCE)
      end
    end
  end
end
```

- [ ] **Step 2: Create generate.cr**

Create `spec/fixtures/generate.cr`:

```crystal
require "digest/sha1"
require "digest/sha256"
require "../support/fixture_builder"

dir = File.dirname(__FILE__)

{
  "v1_single" => {FixtureBuilder.v1_single_info_bytes, false},
  "v1_multi"  => {FixtureBuilder.v1_multi_info_bytes, true},
  "v2_single" => {FixtureBuilder.v2_single_info_bytes, false},
  "hybrid"    => {FixtureBuilder.hybrid_info_bytes, false},
}.each do |name, (info_bytes, announce_list)|
  path = File.join(dir, "#{name}.torrent")
  FixtureBuilder.write_torrent(path, info_bytes, announce_list)
  sha1 = Digest::SHA1.digest(info_bytes).map { |b| "%02x" % b }.join
  sha256 = Digest::SHA256.digest(info_bytes).map { |b| "%02x" % b }.join
  puts "#{name}.torrent: sha1=#{sha1} sha256=#{sha256}"
end

puts "Done. 4 fixtures written to #{dir}"
```

- [ ] **Step 3: Run the generator**

```bash
crystal run spec/fixtures/generate.cr
```

Expected: 4 `.torrent` files created; SHA1/SHA256 hashes printed to stdout.

- [ ] **Step 4: Verify the fixture files exist and are non-empty**

```bash
ls -la spec/fixtures/*.torrent
```

Expected: 4 files, all > 0 bytes.

- [ ] **Step 5: Commit**

```bash
git add spec/support/fixture_builder.cr spec/fixtures/generate.cr spec/fixtures/*.torrent
git commit -m "feat: test fixture builder and generated .torrent files"
```

---

## Task 5: TorrentFile and Torrent (v1)

**Files:**
- Create: `src/torinfo/torrent_file.cr`
- Create: `src/torinfo/torrent.cr`
- Create: `spec/torinfo/torrent_spec.cr`

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/torrent_spec.cr`:

```crystal
require "./spec_helper"
require "../support/fixture_builder"
require "digest/sha1"
require "digest/sha256"

Spectator.describe Torinfo::Torrent do
  describe ".from_file (v1 single-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }

    it "reads the name" do
      expect(torrent.name).to eq("test-file.txt")
    end

    it "sets format_version to 1" do
      expect(torrent.format_version).to eq(1)
    end

    it "computes the v1 info hash" do
      expected = Digest::SHA1.digest(FixtureBuilder.v1_single_info_bytes)
      expect(torrent.info_hash_v1.not_nil!.bytes).to eq(expected)
    end

    it "returns nil for v2 info hash" do
      expect(torrent.info_hash_v2).to be_nil
    end

    it "returns hash prefixed with 'v1 '" do
      expect(torrent.hash).to start_with("v1 ")
      expect(torrent.hash.size).to eq(43)  # "v1 " + 40 hex chars
    end

    it "reads piece_size" do
      expect(torrent.piece_size).to eq(262144_i64)
    end

    it "reads piece_count" do
      expect(torrent.piece_count).to eq(1_i64)
    end

    it "reads total_size" do
      expect(torrent.total_size).to eq(1024_i64)
    end

    it "reads created_by" do
      expect(torrent.created_by).to eq("torinfo-test")
    end

    it "reads created_on as UTC Time" do
      time = torrent.created_on
      expect(time).not_to be_nil
      expect(time.not_nil!.to_unix).to eq(1704067200_i64)
    end

    it "reads comment" do
      expect(torrent.comment).to eq("test torrent")
    end

    it "reads source" do
      expect(torrent.source).to eq("TEST")
    end

    it "is not private" do
      expect(torrent.private?).to be_false
    end

    it "returns 'public' visibility" do
      expect(torrent.visibility).to eq("public")
    end

    it "reads trackers" do
      expect(torrent.trackers).to eq(["https://tracker.example.com/announce"])
    end

    it "has one file entry" do
      expect(torrent.files.size).to eq(1)
    end

    it "file has correct path (torrent name)" do
      expect(torrent.files[0].path).to eq("test-file.txt")
    end

    it "file has correct size" do
      expect(torrent.files[0].size).to eq(1024_i64)
    end

    it "file has no pieces_root (v1 only)" do
      expect(torrent.files[0].pieces_root).to be_nil
    end
  end

  describe ".from_file (v1 multi-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "reads the name" do
      expect(torrent.name).to eq("test-dir")
    end

    it "sets format_version to 1" do
      expect(torrent.format_version).to eq(1)
    end

    it "is private" do
      expect(torrent.private?).to be_true
    end

    it "returns 'private' visibility" do
      expect(torrent.visibility).to eq("private")
    end

    it "reads total_size as sum of files" do
      expect(torrent.total_size).to eq(3500_i64)
    end

    it "has three file entries" do
      expect(torrent.files.size).to eq(3)
    end

    it "file paths are joined" do
      paths = torrent.files.map(&.path)
      expect(paths).to contain_exactly("subdir/file1.txt", "subdir/file2.txt", "other.txt")
    end

    it "file sizes are correct" do
      sizes = torrent.files.map(&.size)
      expect(sizes).to contain_exactly(1000_i64, 2000_i64, 500_i64)
    end

    it "dedupes trackers from announce and announce-list" do
      expect(torrent.trackers).to contain("https://tracker.example.com/announce")
      expect(torrent.trackers).to contain("https://backup.example.com/announce")
      expect(torrent.trackers.uniq.size).to eq(torrent.trackers.size)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/torrent_spec.cr -v --error-trace
```

Expected: compilation error — `Torinfo::Torrent` not defined.

- [ ] **Step 3: Implement TorrentFile**

Create `src/torinfo/torrent_file.cr`:

```crystal
module Torinfo
  struct TorrentFile
    getter path : String
    getter size : Int64
    getter pieces_root : ByteString?

    def initialize(@path : String, @size : Int64, @pieces_root : ByteString? = nil)
    end
  end
end
```

- [ ] **Step 4: Implement Torrent (v1)**

Create `src/torinfo/torrent.cr`:

```crystal
require "digest/sha1"
require "digest/sha256"

module Torinfo
  class Torrent
    include Guard

    getter path : String
    getter name : String
    getter format_version : Int32
    getter info_hash_v1 : ByteString?
    getter info_hash_v2 : ByteString?
    getter created_by : String?
    getter created_on : Time?
    getter comment : String?
    getter source : String?
    getter piece_size : Int64
    getter piece_count : Int64
    getter total_size : Int64
    getter? private : Bool
    getter trackers : Array(String)
    getter files : Array(TorrentFile)

    def self.from_file(path : String) : Torrent
      bytes = File.read(path).to_slice
      from_bytes(bytes, path)
    end

    def self.from_bytes(bytes : Bytes, path : String) : Torrent
      parser = BencodeParser.new(bytes)
      root = parser.parse.as(Hash(String, BencodeValue))
      info_raw = parser.info_raw_bytes
      new(root, info_raw, path)
    end

    def hash : String
      if v1 = @info_hash_v1
        "v1 #{v1.hex}"
      elsif v2 = @info_hash_v2
        "v2 #{v2.hex}"
      else
        raise "Torrent has no computable info hash"
      end
    end

    def visibility : String
      @private ? "private" : "public"
    end

    private def initialize(root : Hash(String, BencodeValue), info_raw : Bytes?, path : String)
      @path = path
      info_dict = root["info"].as(Hash(String, BencodeValue))

      @name = bytes_to_s(info_dict["name"].as(Bytes))
      @format_version, @info_hash_v1, @info_hash_v2 = compute_version_and_hashes(info_dict, info_raw)
      @piece_size = info_dict["piece length"].as(Int64)
      @private = info_dict["private"]?.try { |v| v.as(Int64) == 1_i64 } || false

      @created_by = root["created by"]?.try { |v| bytes_to_s(v.as(Bytes)) }
      @created_on = root["creation date"]?.try { |v| Time.unix(v.as(Int64)) }
      @comment = root["comment"]?.try { |v| bytes_to_s(v.as(Bytes)) }
      @source = root["source"]?.try { |v| bytes_to_s(v.as(Bytes)) }

      @trackers = collect_trackers(root)
      @files = collect_files_v1(info_dict)
      @total_size = @files.sum(&.size)
      @piece_count = compute_piece_count(info_dict)
    end

    private def bytes_to_s(bytes : Bytes) : String
      String.new(bytes)
    end

    private def compute_version_and_hashes(info : Hash(String, BencodeValue), raw : Bytes?) : {Int32, ByteString?, ByteString?}
      has_pieces = info.has_key?("pieces")
      has_meta_v2 = info["meta version"]?.try { |v| v.as(Int64) == 2_i64 } || false

      version = 0
      version |= 1 if has_pieces
      version |= 2 if has_meta_v2

      v1_hash = nil
      v2_hash = nil
      if info_bytes = raw
        v1_hash = ByteString.new(Digest::SHA1.digest(info_bytes)) if has_pieces
        v2_hash = ByteString.new(Digest::SHA256.digest(info_bytes)) if has_meta_v2
      end

      {version, v1_hash, v2_hash}
    end

    private def collect_trackers(root : Hash(String, BencodeValue)) : Array(String)
      result = [] of String
      if announce = root["announce"]?
        result << bytes_to_s(announce.as(Bytes))
      end
      if announce_list = root["announce-list"]?
        announce_list.as(Array(BencodeValue)).each do |tier|
          tier.as(Array(BencodeValue)).each do |url|
            tracker = bytes_to_s(url.as(Bytes))
            result << tracker unless result.includes?(tracker)
          end
        end
      end
      result.uniq!
      result
    end

    private def collect_files_v1(info : Hash(String, BencodeValue)) : Array(TorrentFile)
      if files_list = info["files"]?
        # Multi-file mode
        files_list.as(Array(BencodeValue)).map do |file_entry|
          fdict = file_entry.as(Hash(String, BencodeValue))
          size = fdict["length"].as(Int64)
          path_parts = fdict["path"].as(Array(BencodeValue)).map { |p| bytes_to_s(p.as(Bytes)) }
          TorrentFile.new(path: path_parts.join("/"), size: size)
        end
      else
        # Single-file mode
        [TorrentFile.new(path: @name, size: info["length"].as(Int64))]
      end
    end

    private def compute_piece_count(info : Hash(String, BencodeValue)) : Int64
      if pieces_bytes = info["pieces"]?.try(&.as(Bytes))
        (pieces_bytes.size / 20_i64).to_i64
      else
        # v2-only: derive from file sizes and piece length
        total = @files.sum(&.size)
        ((total + @piece_size - 1) / @piece_size).to_i64
      end
    end
  end
end
```

Update `src/torinfo.cr`:

```crystal
require "./torinfo/byte_string"
require "./torinfo/bencode"
require "./torinfo/torrent_file"
require "./torinfo/torrent"

module Torinfo
  VERSION = "0.1.0"
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/torrent_spec.cr -v --error-trace
```

Expected: all v1 examples pass.

- [ ] **Step 6: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/torrent_file.cr src/torinfo/torrent.cr
```

- [ ] **Step 7: Commit**

```bash
git add src/torinfo/torrent_file.cr src/torinfo/torrent.cr src/torinfo.cr spec/torinfo/torrent_spec.cr
git commit -m "feat: TorrentFile struct and Torrent class (v1 parsing)"
```

---

## Task 6: Torrent v2 / Hybrid Support

**Files:**
- Modify: `src/torinfo/torrent.cr`
- Modify: `spec/torinfo/torrent_spec.cr`

- [ ] **Step 1: Add failing tests for v2 and hybrid**

Add to `spec/torinfo/torrent_spec.cr`:

```crystal
  describe ".from_file (v2 single-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v2_single.torrent") }

    it "sets format_version to 2" do
      expect(torrent.format_version).to eq(2)
    end

    it "returns nil for v1 info hash" do
      expect(torrent.info_hash_v1).to be_nil
    end

    it "computes the v2 info hash" do
      expected = Digest::SHA256.digest(FixtureBuilder.v2_single_info_bytes)
      expect(torrent.info_hash_v2.not_nil!.bytes).to eq(expected)
    end

    it "returns hash prefixed with 'v2 '" do
      expect(torrent.hash).to start_with("v2 ")
      expect(torrent.hash.size).to eq(67)  # "v2 " + 64 hex chars
    end

    it "reads name" do
      expect(torrent.name).to eq("test-file-v2.txt")
    end

    it "has one file entry from file tree" do
      expect(torrent.files.size).to eq(1)
    end

    it "file has correct path from file tree key" do
      expect(torrent.files[0].path).to eq("test-file-v2.txt")
    end

    it "file has correct size" do
      expect(torrent.files[0].size).to eq(1024_i64)
    end

    it "file has a pieces_root" do
      pr = torrent.files[0].pieces_root
      expect(pr).not_to be_nil
      expect(pr.not_nil!.bytes.size).to eq(32)
    end
  end

  describe ".from_file (hybrid)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/hybrid.torrent") }

    it "sets format_version to 3" do
      expect(torrent.format_version).to eq(3)
    end

    it "has a v1 info hash" do
      expected = Digest::SHA1.digest(FixtureBuilder.hybrid_info_bytes)
      expect(torrent.info_hash_v1.not_nil!.bytes).to eq(expected)
    end

    it "has a v2 info hash" do
      expected = Digest::SHA256.digest(FixtureBuilder.hybrid_info_bytes)
      expect(torrent.info_hash_v2.not_nil!.bytes).to eq(expected)
    end

    it "prefers v1 in .hash" do
      expect(torrent.hash).to start_with("v1 ")
    end

    it "reads files from file tree" do
      expect(torrent.files.size).to eq(1)
      expect(torrent.files[0].path).to eq("hybrid-file.txt")
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
crystal spec spec/torinfo/torrent_spec.cr -v --error-trace 2>&1 | grep -E "(FAILED|Error)"
```

Expected: v2 and hybrid tests fail.

- [ ] **Step 3: Add v2 file collection to Torrent**

Add the following private method to `src/torinfo/torrent.cr` (inside `Torinfo::Torrent`):

```crystal
    private def collect_files_v2(info : Hash(String, BencodeValue)) : Array(TorrentFile)
      file_tree = info["file tree"].as(Hash(String, BencodeValue))
      collect_file_tree(file_tree, [] of String)
    end

    private def collect_file_tree(tree : Hash(String, BencodeValue), prefix : Array(String)) : Array(TorrentFile)
      result = [] of TorrentFile
      tree.each do |key, value|
        sub_dict = value.as(Hash(String, BencodeValue))
        current_path = prefix + [key]
        if file_entry = sub_dict[""]?
          # Leaf node: this is a file
          meta = file_entry.as(Hash(String, BencodeValue))
          size = meta["length"].as(Int64)
          pieces_root = meta["pieces root"]?.try { |pr| ByteString.new(pr.as(Bytes)) }
          result << TorrentFile.new(path: current_path.join("/"), size: size, pieces_root: pieces_root)
        else
          # Directory node: recurse
          result.concat(collect_file_tree(sub_dict, current_path))
        end
      end
      result
    end
```

Replace `collect_files_v1` call in `initialize` with version-aware dispatch:

```crystal
      @files = collect_files(info_dict, @format_version)
```

Add the dispatch method:

```crystal
    private def collect_files(info : Hash(String, BencodeValue), version : Int32) : Array(TorrentFile)
      if version >= 2 && info.has_key?("file tree")
        collect_files_v2(info)
      else
        collect_files_v1(info)
      end
    end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/torrent_spec.cr -v --error-trace
```

Expected: all examples pass.

- [ ] **Step 5: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/torrent.cr
```

- [ ] **Step 6: Commit**

```bash
git add src/torinfo/torrent.cr spec/torinfo/torrent_spec.cr
git commit -m "feat: Torrent v2 and hybrid support (file tree, SHA-256 info hash)"
```

---

## Task 7: TextFormatter

**Files:**
- Create: `src/torinfo/formatters/text.cr`
- Create: `spec/torinfo/formatters/text_spec.cr`

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/formatters/text_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::Formatters::Text do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(formatter) { Torinfo::Formatters::Text.new }

  describe "#format_one" do
    it "includes the torrent name" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Name: test-file\.txt/)
    end

    it "includes the hash with v1 prefix" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Hash: v1 [0-9a-f]{40}/)
    end

    it "includes visibility" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Visibility: public/)
    end

    it "includes numbered trackers" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Trackers:\n  1\. https:\/\/tracker\.example\.com/)
    end

    it "includes numbered files" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Files:\n  1\..*test-file\.txt/)
    end

    it "includes timestamp in RFC 3339 by default" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 2024-01-01T00:00:00Z/)
    end

    context "with field selection" do
      it "outputs only selected fields" do
        io = IO::Memory.new
        formatter.format_one(torrent, io, fields: [:name, :hash])
        output = io.to_s
        expect(output).to match(/Name:/)
        expect(output).to match(/Hash:/)
        expect(output).not_to match(/Visibility:/)
        expect(output).not_to match(/Trackers:/)
      end
    end
  end

  describe "#format_all" do
    it "adds ==== headers when multiple torrents" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io)
      expect(io.to_s).to match(/====.*v1_single\.torrent.*====/)
      expect(io.to_s).to match(/====.*v1_multi\.torrent.*====/)
    end

    it "omits ==== header for a single torrent" do
      io = IO::Memory.new
      formatter.format_all([torrent], io)
      expect(io.to_s).not_to match(/====/)
    end
  end

  describe "timestamp formatting" do
    it "uses strftime format when provided" do
      io = IO::Memory.new
      formatter.time_format = "%Y-%m-%d"
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 2024-01-01/)
      expect(io.to_s).not_to match(/T00:00:00/)
    end

    it "uses unix epoch when unix_epoch? is true" do
      io = IO::Memory.new
      formatter.unix_epoch = true
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 1704067200/)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/formatters/text_spec.cr -v --error-trace
```

Expected: compilation error.

- [ ] **Step 3: Implement TextFormatter**

Create `src/torinfo/formatters/text.cr`:

```crystal
module Torinfo
  module Formatters
    class Text
      property time_format : String?
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Symbol) = [] of Symbol) : Nil
        torrents.each_with_index do |torrent, index|
          io << "==== #{torrent.path} ====\n" if torrents.size > 1
          format_one(torrent, io, fields: fields)
          io << '\n' if index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Symbol) = [] of Symbol) : Nil
        show_all = fields.empty?

        emit(io, "Name", torrent.name) if show_all || fields.includes?(:name)
        emit(io, "Format", format_version_label(torrent.format_version)) if show_all
        emit(io, "Hash", torrent.hash) if show_all || fields.includes?(:hash)
        emit(io, "Created By", torrent.created_by) if show_all || fields.includes?(:created_by)
        emit_time(io, "Created On", torrent.created_on) if show_all || fields.includes?(:created_on)
        emit(io, "Comment", torrent.comment) if show_all || fields.includes?(:comment)
        emit(io, "Source", torrent.source) if show_all || fields.includes?(:source)
        emit(io, "Piece Count", torrent.piece_count.to_s) if show_all || fields.includes?(:piece_count)
        emit(io, "Piece Size", torrent.piece_size.to_s) if show_all || fields.includes?(:piece_size)
        emit(io, "Total Size", torrent.total_size.to_s) if show_all || fields.includes?(:total_size)
        emit(io, "Visibility", torrent.visibility) if show_all || fields.includes?(:visibility)

        if show_all || fields.includes?(:trackers)
          unless torrent.trackers.empty?
            io << "Trackers:\n"
            torrent.trackers.each_with_index(offset: 1) do |url, num|
              io << "  #{num}. #{url}\n"
            end
          end
        end

        if show_all || fields.includes?(:files)
          unless torrent.files.empty?
            io << "Files:\n"
            torrent.files.each_with_index(offset: 1) do |file, num|
              io << "  #{num}. #{file.size}  #{file.path}\n"
            end
          end
        end
      end

      private def emit(io : IO, label : String, value : String?) : Nil
        return if value.nil? || value.empty?
        io << "#{label}: #{value}\n"
      end

      private def emit_time(io : IO, label : String, time : Time?) : Nil
        return unless time
        formatted = if @unix_epoch
          time.to_unix.to_s
        elsif fmt = @time_format
          time.to_s(fmt)
        else
          time.to_rfc3339
        end
        io << "#{label}: #{formatted}\n"
      end

      private def format_version_label(version : Int32) : String
        case version
        when 1 then "v1"
        when 2 then "v2"
        when 3 then "hybrid"
        else        "unknown"
        end
      end
    end
  end
end
```

Update `src/torinfo.cr` to require the formatters directory (add after torrent.cr):

```crystal
require "./torinfo/formatters/text"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/formatters/text_spec.cr -v --error-trace
```

- [ ] **Step 5: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/formatters/text.cr
```

- [ ] **Step 6: Commit**

```bash
git add src/torinfo/formatters/text.cr src/torinfo.cr spec/torinfo/formatters/text_spec.cr
git commit -m "feat: TextFormatter with field selection and timestamp options"
```

---

## Task 8: JsonFormatter

**Files:**
- Create: `src/torinfo/formatters/json.cr`
- Create: `spec/torinfo/formatters/json_spec.cr`

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/formatters/json_spec.cr`:

```crystal
require "./spec_helper"
require "json"

Spectator.describe Torinfo::Formatters::Json do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::Json.new }

  describe "#format_one" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      io.to_s
    end

    it "emits valid JSON" do
      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes name" do
      expect(JSON.parse(output)["name"].as_s).to eq("test-file.txt")
    end

    it "includes hash" do
      expect(JSON.parse(output)["hash"].as_s).to start_with("v1 ")
    end

    it "includes format_version" do
      expect(JSON.parse(output)["format_version"].as_i).to eq(1)
    end

    it "includes visibility" do
      expect(JSON.parse(output)["visibility"].as_s).to eq("public")
    end

    it "includes trackers as array" do
      trackers = JSON.parse(output)["trackers"].as_a
      expect(trackers.first.as_s).to eq("https://tracker.example.com/announce")
    end

    it "includes files as array of objects" do
      files = JSON.parse(output)["files"].as_a
      expect(files.size).to eq(1)
      expect(files[0]["path"].as_s).to eq("test-file.txt")
      expect(files[0]["size"].as_i64).to eq(1024_i64)
    end

    it "uses null for nil fields" do
      parsed = JSON.parse(output)
      expect(parsed["info_hash_v2"]).to eq(JSON::Any.new(nil))
    end

    it "includes created_on in RFC 3339 by default" do
      expect(JSON.parse(output)["created_on"].as_s).to eq("2024-01-01T00:00:00Z")
    end
  end

  describe "#format_all (NDJSON)" do
    it "emits one JSON object per line" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/formatters/json_spec.cr -v --error-trace
```

- [ ] **Step 3: Implement JsonFormatter**

Create `src/torinfo/formatters/json.cr`:

```crystal
require "json"

module Torinfo
  module Formatters
    class Json
      property time_format : String?
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO) : Nil
        torrents.each { |torrent| format_one(torrent, io) }
      end

      def format_one(torrent : Torrent, io : IO) : Nil
        JSON.build(io) do |json|
          json.object do
            json.field "name", torrent.name
            json.field "format_version", torrent.format_version
            json.field "hash", torrent.hash
            json.field "info_hash_v1", torrent.info_hash_v1.try(&.hex)
            json.field "info_hash_v2", torrent.info_hash_v2.try(&.hex)
            json.field "created_by", torrent.created_by
            json.field "created_on", format_time(torrent.created_on)
            json.field "comment", torrent.comment
            json.field "source", torrent.source
            json.field "piece_count", torrent.piece_count
            json.field "piece_size", torrent.piece_size
            json.field "total_size", torrent.total_size
            json.field "visibility", torrent.visibility
            json.field "private", torrent.private?
            json.field "trackers", torrent.trackers
            json.field "files" do
              json.array do
                torrent.files.each do |file|
                  json.object do
                    json.field "path", file.path
                    json.field "size", file.size
                    json.field "pieces_root", file.pieces_root.try(&.hex)
                  end
                end
              end
            end
          end
        end
        io << '\n'
      end

      private def format_time(time : Time?) : String?
        return nil unless time
        if @unix_epoch
          time.to_unix.to_s
        elsif fmt = @time_format
          time.to_s(fmt)
        else
          time.to_rfc3339
        end
      end
    end
  end
end
```

Add to `src/torinfo.cr`:

```crystal
require "./torinfo/formatters/json"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/formatters/json_spec.cr -v --error-trace
```

- [ ] **Step 5: Format, lint, commit**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/formatters/json.cr
git add src/torinfo/formatters/json.cr src/torinfo.cr spec/torinfo/formatters/json_spec.cr
git commit -m "feat: JsonFormatter (NDJSON for multiple torrents)"
```

---

## Task 9: BashVarsFormatter

**Files:**
- Create: `src/torinfo/formatters/bash_vars.cr`
- Create: `spec/torinfo/formatters/bash_vars_spec.cr`

**Quoting helper** (shared with BashFuncFormatter):
- String values: `'value'` with `'` escaped as `'\''`
- Integer values: bare number (no quotes)
- Array values: `('elem1' 'elem2')`
- Empty string: `''`

**Prefix expansion rules:**
- Single file: use prefix as-is (e.g., `tfile_`)
- Multiple files + prefix has `%d` pattern (regex `/\A.*%0*\d*d.*\z/`): `sprintf(prefix, index)` (1-based)
- Multiple files + no `%d`: append `_1`, `_2`, … to prefix

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/formatters/bash_vars_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::Formatters::BashVars do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::BashVars.new }

  describe "#format_one (non-TTY, single file)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: false)
      io.to_s
    end

    it "includes all scalar variables on one line" do
      expect(output).to match(/t_name='test-file\.txt'/)
      expect(output).to match(/t_hash='v1 [0-9a-f]{40}'/)
      expect(output).to match(/t_visibility=public/)
      expect(output).to match(/t_format_version=1/)
      expect(output).to match(/t_piece_count=1/)
    end

    it "includes path variable" do
      expect(output).to match(/t_path='spec\/fixtures\/v1_single\.torrent'/)
    end

    it "includes arrays" do
      expect(output).to match(/t_trackers=\('https:\/\/tracker\.example\.com\/announce'\)/)
      expect(output).to match(/t_filename=\('test-file\.txt'\)/)
      expect(output).to match(/t_filesize=\(1024\)/)
    end

    it "puts everything on one line" do
      expect(output.strip.count('\n')).to eq(0)
    end
  end

  describe "#format_one (TTY, single file)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: true)
      io.to_s
    end

    it "starts with path variable" do
      expect(output.lines.first).to match(/t_path=.*\\$/)
    end

    it "indents subsequent variables with two spaces" do
      output.lines[1..].each { |line| expect(line).to start_with("  t_") }
    end

    it "ends with no trailing backslash on last line" do
      expect(output.lines.last.strip).not_to end_with('\\')
    end
  end

  describe "#format_all (multiple files, no %d in prefix)" do
    let(torrent2) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "appends _1, _2 suffixes in non-TTY mode" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_", tty: false)
      output = io.to_s
      expect(output).to match(/t_1_name=/)
      expect(output).to match(/t_2_name=/)
    end

    it "separates entries with a blank line in TTY mode" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_", tty: true)
      expect(io.to_s).to match(/\n\n/)
    end
  end

  describe "#format_all (multiple files, %d in prefix)" do
    let(torrent2) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "uses sprintf formatting for prefix" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_%02d_", tty: false)
      output = io.to_s
      expect(output).to match(/t_01_name=/)
      expect(output).to match(/t_02_name=/)
    end
  end

  describe "quoting" do
    it "escapes single quotes in string values" do
      # Test via a torrent whose name contains a single quote
      # (done by calling the quoting helper directly)
      expect(formatter.bash_quote("it's here")).to eq("'it'\\''s here'")
    end

    it "does not quote integer-valued variables" do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: false)
      expect(io.to_s).to match(/t_piece_count=1 /)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/formatters/bash_vars_spec.cr -v --error-trace
```

- [ ] **Step 3: Implement BashVarsFormatter**

Create `src/torinfo/formatters/bash_vars.cr`:

```crystal
module Torinfo
  module Formatters
    class BashVars
      property time_format : String?
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, prefix : String, tty : Bool) : Nil
        effective_prefix = resolve_prefix_strategy(prefix, torrents.size)
        torrents.each_with_index do |torrent, index|
          pfx = case effective_prefix
                in :as_is then prefix
                in String  then effective_prefix % (index + 1)
                in :suffix then "#{prefix}#{index + 1}_"
                end
          format_one(torrent, io, prefix: pfx, tty: tty)
          io << '\n' if tty && index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, prefix : String, tty : Bool) : Nil
        assignments = build_assignments(torrent, prefix)
        if tty
          assignments.each_with_index do |pair, index|
            name, value = pair
            if index == 0
              io << "#{name}=#{value}"
            else
              io << " \\\n  #{name}=#{value}"
            end
          end
          io << '\n'
        else
          io << assignments.map { |name, value| "#{name}=#{value}" }.join(' ') << '\n'
        end
      end

      def bash_quote(str : String) : String
        "'#{str.gsub("'", "'\\''")}'"
      end

      private def resolve_prefix_strategy(prefix : String, count : Int32) : :as_is | String | :suffix
        return :as_is if count == 1
        if prefix =~ /\A.*%0*\d*d.*\z/
          prefix  # will sprintf with index+1
        else
          :suffix
        end
      end

      private def build_assignments(torrent : Torrent, prefix : String) : Array({String, String})
        time_str = format_time(torrent.created_on)
        [
          {"#{prefix}path", bash_quote(torrent.path)},
          {"#{prefix}name", bash_quote(torrent.name)},
          {"#{prefix}hash", bash_quote(torrent.hash)},
          {"#{prefix}created_by", bash_quote(torrent.created_by || "")},
          {"#{prefix}created_on", bash_quote(time_str)},
          {"#{prefix}comment", bash_quote(torrent.comment || "")},
          {"#{prefix}source", bash_quote(torrent.source || "")},
          {"#{prefix}piece_count", torrent.piece_count.to_s},
          {"#{prefix}piece_size", torrent.piece_size.to_s},
          {"#{prefix}total_size", torrent.total_size.to_s},
          {"#{prefix}visibility", torrent.visibility},
          {"#{prefix}format_version", torrent.format_version.to_s},
          {"#{prefix}trackers", bash_array(torrent.trackers)},
          {"#{prefix}filename", bash_array(torrent.files.map(&.path))},
          {"#{prefix}filesize", bash_int_array(torrent.files.map(&.size))},
        ]
      end

      private def bash_array(items : Array(String)) : String
        "(#{items.map { |item| bash_quote(item) }.join(' ')})"
      end

      private def bash_int_array(items : Array(Int64)) : String
        "(#{items.map(&.to_s).join(' ')})"
      end

      private def format_time(time : Time?) : String
        return "" unless time
        if @unix_epoch
          time.to_unix.to_s
        elsif fmt = @time_format
          time.to_s(fmt)
        else
          time.to_rfc3339
        end
      end
    end
  end
end
```

Add to `src/torinfo.cr`:

```crystal
require "./torinfo/formatters/bash_vars"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/formatters/bash_vars_spec.cr -v --error-trace
```

- [ ] **Step 5: Format, lint, commit**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/formatters/bash_vars.cr
git add src/torinfo/formatters/bash_vars.cr src/torinfo.cr spec/torinfo/formatters/bash_vars_spec.cr
git commit -m "feat: BashVarsFormatter with TTY/non-TTY, prefix expansion, quoting"
```

---

## Task 10: BashFuncFormatter

**Files:**
- Create: `src/torinfo/formatters/bash_func.cr`
- Create: `spec/torinfo/formatters/bash_func_spec.cr`

**Argument order:**
`path name hash created_by created_on comment source piece_count piece_size total_size visibility format_version [trackers...] -- [file_path file_size ...]`

**Non-TTY:** all args on one line separated by spaces, each string single-quoted, integers bare.

**TTY:** first arg on same line as function name, subsequent args indented to align under first arg (one per line), `\` continuation on all but last.

- [ ] **Step 1: Write the failing tests**

Create `spec/torinfo/formatters/bash_func_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::Formatters::BashFunc do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::BashFunc.new }

  describe "#format_one (non-TTY)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, func_name: "myfunc", tty: false)
      io.to_s
    end

    it "starts with the function name" do
      expect(output).to start_with("myfunc ")
    end

    it "is a single line" do
      expect(output.strip.count('\n')).to eq(0)
    end

    it "contains the path as first argument" do
      expect(output).to match(/myfunc 'spec\/fixtures\/v1_single\.torrent' /)
    end

    it "contains -- separator before files" do
      expect(output).to match(/ -- /)
    end

    it "contains file path and size after --" do
      expect(output).to match(/-- 'test-file\.txt' 1024$/)
    end

    it "contains piece_count as bare integer" do
      expect(output).to match(/ 1 /)  # piece_count = 1
    end
  end

  describe "#format_one (TTY)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, func_name: "myfunc", tty: true)
      io.to_s
    end

    it "starts with function name and first argument" do
      expect(output.lines.first).to match(/\Amyfunc '.*' \\$/)
    end

    it "indents continuation lines to align under first arg" do
      indent = "myfunc ".size
      output.lines[1...-1].each { |line| expect(line).to start_with(" " * indent) }
    end

    it "last line has no trailing backslash" do
      expect(output.lines.last.strip).not_to end_with('\\')
    end

    it "has -- on its own continuation line" do
      lines = output.lines
      expect(lines.any? { |line| line.strip == "-- \\" || line.strip == "--" }).to be_true
    end
  end

  describe "#format_all" do
    it "calls function once per torrent (non-TTY)" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, func_name: "myfunc", tty: false)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect(line).to start_with("myfunc ") }
    end

    it "separates torrent calls with blank line in TTY mode" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, func_name: "myfunc", tty: true)
      expect(io.to_s).to match(/\n\n/)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/formatters/bash_func_spec.cr -v --error-trace
```

- [ ] **Step 3: Implement BashFuncFormatter**

Create `src/torinfo/formatters/bash_func.cr`:

```crystal
module Torinfo
  module Formatters
    class BashFunc
      property time_format : String?
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, func_name : String, tty : Bool) : Nil
        torrents.each_with_index do |torrent, index|
          format_one(torrent, io, func_name: func_name, tty: tty)
          io << '\n' if tty && index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, func_name : String, tty : Bool) : Nil
        args = build_args(torrent)
        if tty
          indent = " " * (func_name.size + 1)
          io << func_name << ' ' << args.first << " \\\n"
          args[1...-1].each { |arg| io << indent << arg << " \\\n" }
          io << indent << args.last << '\n'
        else
          io << func_name << ' ' << args.join(' ') << '\n'
        end
      end

      private def build_args(torrent : Torrent) : Array(String)
        q = ->(str : String) { bash_quote(str) }
        time_str = format_time(torrent.created_on)

        args = [
          q.call(torrent.path),
          q.call(torrent.name),
          q.call(torrent.hash),
          q.call(torrent.created_by || ""),
          q.call(time_str),
          q.call(torrent.comment || ""),
          q.call(torrent.source || ""),
          torrent.piece_count.to_s,
          torrent.piece_size.to_s,
          torrent.total_size.to_s,
          torrent.visibility,
          torrent.format_version.to_s,
        ]

        torrent.trackers.each { |url| args << q.call(url) }
        args << "--"
        torrent.files.each { |file| args << q.call(file.path) << file.size.to_s }

        args
      end

      private def bash_quote(str : String) : String
        "'#{str.gsub("'", "'\\''")}'"
      end

      private def format_time(time : Time?) : String
        return "" unless time
        if @unix_epoch
          time.to_unix.to_s
        elsif fmt = @time_format
          time.to_s(fmt)
        else
          time.to_rfc3339
        end
      end
    end
  end
end
```

Add to `src/torinfo.cr`:

```crystal
require "./torinfo/formatters/bash_func"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/formatters/bash_func_spec.cr -v --error-trace
```

- [ ] **Step 5: Format, lint, commit**

```bash
crystal tool format && lib/ameba/bin/ameba src/torinfo/formatters/bash_func.cr
git add src/torinfo/formatters/bash_func.cr src/torinfo.cr spec/torinfo/formatters/bash_func_spec.cr
git commit -m "feat: BashFuncFormatter with TTY/non-TTY and per-file function calls"
```

---

## Task 11: CLI

**Files:**
- Create: `src/torinfo/cli.cr`
- Create: `src/torinfo_cli.cr`
- Create: `spec/torinfo/cli_spec.cr`

- [ ] **Step 1: Write failing CLI tests**

Create `spec/torinfo/cli_spec.cr`:

```crystal
require "./spec_helper"

Spectator.describe Torinfo::CLI do
  describe "#initialize" do
    it "defaults to text output" do
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --json" do
      cli = Torinfo::CLI.new(["--json", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:json)
    end

    it "parses --text" do
      cli = Torinfo::CLI.new(["--text", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --bashv with prefix" do
      cli = Torinfo::CLI.new(["--bashv", "t_", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_vars)
      expect(cli.bash_prefix).to eq("t_")
    end

    it "parses --bashf with function name" do
      cli = Torinfo::CLI.new(["--bashf", "myfunc", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_func)
      expect(cli.bash_func_name).to eq("myfunc")
    end

    it "collects field flags" do
      cli = Torinfo::CLI.new(["--name", "--hash", "spec/fixtures/v1_single.torrent"])
      expect(cli.fields).to contain_exactly(:name, :hash)
    end

    it "parses --strftime format" do
      cli = Torinfo::CLI.new(["--strftime", "%Y-%m-%d", "spec/fixtures/v1_single.torrent"])
      expect(cli.time_format).to eq("%Y-%m-%d")
    end

    it "parses --unix-epoch" do
      cli = Torinfo::CLI.new(["--unix-epoch", "spec/fixtures/v1_single.torrent"])
      expect(cli.unix_epoch?).to be_true
    end

    it "raises ArgumentError for --bashv with field specifiers" do
      expect {
        Torinfo::CLI.new(["--bashv", "t_", "--name", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /cannot combine/)
    end

    it "raises ArgumentError for --bashf with field specifiers" do
      expect {
        Torinfo::CLI.new(["--bashf", "f", "--hash", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /cannot combine/)
    end

    it "raises ArgumentError for unknown option" do
      expect {
        Torinfo::CLI.new(["--nope", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /unknown option/)
    end

    it "raises ArgumentError for --bashv without prefix argument" do
      expect {
        Torinfo::CLI.new(["--bashv"])
      }.to raise_error(ArgumentError, /requires/)
    end

    it "collects torrent file paths" do
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(cli.torrent_paths).to eq(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
    end
  end

  describe "#run" do
    it "outputs text for a torrent file" do
      io = IO::Memory.new
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent"])
      cli.run(io)
      expect(io.to_s).to match(/Name: test-file\.txt/)
    end

    it "outputs JSON when --json" do
      io = IO::Memory.new
      cli = Torinfo::CLI.new(["--json", "spec/fixtures/v1_single.torrent"])
      cli.run(io)
      expect { JSON.parse(io.to_s) }.not_to raise_error
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
crystal spec spec/torinfo/cli_spec.cr -v --error-trace
```

- [ ] **Step 3: Implement CLI**

Create `src/torinfo/cli.cr`:

```crystal
require "json"

module Torinfo
  HELP = <<-HELP
    torinfo - tool to read BitTorrent files

    Usage: torinfo [options] <torrentfile...>

    Options

      --help, -h                      Show this help

      --files                         List the files
      --name, --hash, --created-by,
      --created-on, --comment,
      --source, --piece-count,
      --piece-size, --total-size,
      --visibility, --trackers        Show one or more fields

      --text                          Output values as human-readable text (DEFAULT)
      --bashv PREFIX                  Output bash variable assignments suitable for eval
      --bashf FUNCTION                Output bash function call suitable for eval
      --json                          Output JSON

      --strftime FORMAT               Format timestamps using strftime-style FORMAT
      --unix-epoch                    Format timestamps as seconds since Unix epoch

    Notes:
      --bashv and --bashf cannot be combined with field specifiers.
    HELP

  FIELD_FLAGS = {
    "--name"        => :name,
    "--hash"        => :hash,
    "--created-by"  => :created_by,
    "--created-on"  => :created_on,
    "--comment"     => :comment,
    "--source"      => :source,
    "--piece-count" => :piece_count,
    "--piece-size"  => :piece_size,
    "--total-size"  => :total_size,
    "--visibility"  => :visibility,
    "--trackers"    => :trackers,
    "--files"       => :files,
  }

  class CLI
    getter output_format : Symbol = :text
    getter bash_prefix : String = ""
    getter bash_func_name : String = ""
    getter fields : Array(Symbol) = [] of Symbol
    getter time_format : String?
    getter? unix_epoch : Bool = false
    getter torrent_paths : Array(String) = [] of String

    def initialize(opts = ARGV.dup)
      while opt = opts.shift?
        case opt
        when "--help", "-h"
          puts HELP
          exit 0
        when "--text"
          @output_format = :text
        when "--json"
          @output_format = :json
        when "--bashv"
          @output_format = :bash_vars
          @bash_prefix = opts.shift? || raise ArgumentError.new("--bashv requires a PREFIX argument")
        when "--bashf"
          @output_format = :bash_func
          @bash_func_name = opts.shift? || raise ArgumentError.new("--bashf requires a FUNCTION argument")
        when "--strftime"
          @time_format = opts.shift? || raise ArgumentError.new("--strftime requires a FORMAT argument")
        when "--unix-epoch"
          @unix_epoch = true
        when *FIELD_FLAGS.keys
          @fields << FIELD_FLAGS[opt]
        when /\A--/
          raise ArgumentError.new("#{opt}: unknown option")
        else
          @torrent_paths << opt
        end
      end

      if @output_format.in?(:bash_vars, :bash_func) && !@fields.empty?
        raise ArgumentError.new("cannot combine --bashv/--bashf with field specifiers")
      end
    end

    def run(io : IO = STDOUT) : Nil
      torrents = @torrent_paths.map { |path| Torrent.from_file(path) }

      case @output_format
      in :text
        fmt = Formatters::Text.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, fields: @fields)
      in :json
        fmt = Formatters::Json.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io)
      in :bash_vars
        fmt = Formatters::BashVars.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, prefix: @bash_prefix, tty: io.is_a?(IO::FileDescriptor) && io.tty?)
      in :bash_func
        fmt = Formatters::BashFunc.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, func_name: @bash_func_name, tty: io.is_a?(IO::FileDescriptor) && io.tty?)
      end
    end
  end
end
```

- [ ] **Step 4: Create the entrypoint**

Create `src/torinfo_cli.cr`:

```crystal
require "./torinfo/cli"

begin
  Torinfo::CLI.new.run
rescue ex : ArgumentError
  STDERR.puts "torinfo: #{ex.message}"
  STDERR.puts "Run 'torinfo --help' for usage."
  exit 1
end
```

- [ ] **Step 5: Update src/torinfo.cr to require cli**

Do NOT require cli from the library entry — the CLI is separate. The `src/torinfo.cr` stays as the library entry. Only `src/torinfo_cli.cr` requires the CLI.

Final `src/torinfo.cr`:

```crystal
require "./torinfo/byte_string"
require "./torinfo/bencode"
require "./torinfo/torrent_file"
require "./torinfo/torrent"
require "./torinfo/formatters/text"
require "./torinfo/formatters/json"
require "./torinfo/formatters/bash_vars"
require "./torinfo/formatters/bash_func"

module Torinfo
  VERSION = "0.1.0"
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
crystal spec spec/torinfo/cli_spec.cr -v --error-trace
```

- [ ] **Step 7: Build the binary and smoke-test**

```bash
shards build --error-trace
bin/torinfo --help
bin/torinfo spec/fixtures/v1_single.torrent
bin/torinfo --json spec/fixtures/v1_single.torrent
bin/torinfo --name --hash spec/fixtures/v1_single.torrent
bin/torinfo --bashv t_ spec/fixtures/v1_single.torrent
bin/torinfo --bashf myfunc spec/fixtures/v1_single.torrent
```

- [ ] **Step 8: Format and lint**

```bash
crystal tool format && lib/ameba/bin/ameba src/ spec/
```

- [ ] **Step 9: Commit**

```bash
git add src/torinfo/cli.cr src/torinfo_cli.cr src/torinfo.cr spec/torinfo/cli_spec.cr
git commit -m "feat: CLI with all flags, formatters, error handling"
```

---

## Task 12: Full Test Suite and Format Pass

**Files:** All source and spec files.

- [ ] **Step 1: Run the full test suite**

```bash
crystal spec -v --error-trace
```

Expected: all examples pass.

- [ ] **Step 2: Format all files**

```bash
crystal tool format
```

- [ ] **Step 3: Run ameba on all files**

```bash
lib/ameba/bin/ameba src/ spec/
```

Fix any reported issues except `Metrics/CyclomaticComplexity` on large `case` blocks (suppress with `# ameba:disable Metrics/CyclomaticComplexity`).

- [ ] **Step 4: Build and end-to-end smoke test**

```bash
shards build --error-trace

# Text output
bin/torinfo spec/fixtures/v1_single.torrent
bin/torinfo spec/fixtures/v1_multi.torrent
bin/torinfo spec/fixtures/v2_single.torrent
bin/torinfo spec/fixtures/hybrid.torrent

# Multiple files
bin/torinfo spec/fixtures/v1_single.torrent spec/fixtures/v1_multi.torrent

# JSON
bin/torinfo --json spec/fixtures/v1_single.torrent

# Field selection
bin/torinfo --name --hash spec/fixtures/v1_single.torrent
bin/torinfo --visibility spec/fixtures/v1_multi.torrent

# Bash vars
eval "$(bin/torinfo --bashv t_ spec/fixtures/v1_single.torrent)"
echo "$t_name"
echo "${t_filename[0]}"

# Bash func
show() { echo "name=$1 hash=$2"; }
eval "$(bin/torinfo --bashf show spec/fixtures/v1_single.torrent)"

# Timestamp formats
bin/torinfo --created-on spec/fixtures/v1_single.torrent
bin/torinfo --created-on --strftime "%Y-%m-%d" spec/fixtures/v1_single.torrent
bin/torinfo --created-on --unix-epoch spec/fixtures/v1_single.torrent

# Error cases
bin/torinfo --bashv t_ --name spec/fixtures/v1_single.torrent  # should error
bin/torinfo --nope  # should error
```

- [ ] **Step 5: Final commit**

```bash
git add -u
git commit -m "chore: format pass and full smoke-test verification"
```

---

## Implementation Notes

- **Bencode dict key ordering in generators:** Keys MUST be in lexicographic order when writing bencoded dicts. The fixture builder has keys pre-sorted; if adding new keys, maintain the sort order.
- **`Bytes#copy_to(Slice)`** copies bytes into a target slice in Crystal — used to produce owned copies from the parser's raw bytes.
- **`IO::FileDescriptor#tty?`** is used for TTY detection; when `run(io)` is called with `IO::Memory` in tests, tty detection returns false (non-TTY path), which is the correct behavior for tests.
- **`Guard` shard:** Include `include Guard` in `Torrent` if nil-access guard patterns are needed. Avoid `.not_nil!` everywhere.
- **ameba suppress pattern** for long case statements: `# ameba:disable Metrics/CyclomaticComplexity` on the line before the `def`.
