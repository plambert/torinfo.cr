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

  TRACKER_URL   = "https://tracker.example.com/announce"
  BACKUP_URL    = "https://backup.example.com/announce"
  CREATED_BY    = "torinfo-test"
  CREATION_DATE = 1704067200_i64 # 2024-01-01 00:00:00 UTC
  COMMENT       = "test torrent"
  SOURCE        = "TEST"
  PIECE_LENGTH  = 262144_i64
  ZERO_SHA1     = Bytes.new(20, 0_u8)
  ZERO_SHA256   = Bytes.new(32, 0_u8)

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
    pieces = Bytes.new(20, 0_u8) # 1 piece for 3500 total bytes with 262144 piece length
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
          Bencode.string(io, "") # empty string = file entry sentinel
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
