require "digest/sha1"
require "digest/sha256"

module Torinfo
  class Torrent
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
      @files = collect_files(info_dict, @format_version)
      @total_size = @files.sum(&.size)
      @piece_count = compute_piece_count(info_dict, @format_version)
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

    private def collect_files(info : Hash(String, BencodeValue), version : Int32) : Array(TorrentFile)
      if version >= 2 && info.has_key?("file tree")
        collect_files_v2(info)
      else
        collect_files_v1(info)
      end
    end

    private def collect_files_v1(info : Hash(String, BencodeValue)) : Array(TorrentFile)
      if files_list = info["files"]?
        files_list.as(Array(BencodeValue)).map do |file_entry|
          fdict = file_entry.as(Hash(String, BencodeValue))
          size = fdict["length"].as(Int64)
          path_parts = fdict["path"].as(Array(BencodeValue)).map { |part| bytes_to_s(part.as(Bytes)) }
          TorrentFile.new(path: path_parts.join("/"), size: size)
        end
      else
        [TorrentFile.new(path: @name, size: info["length"].as(Int64))]
      end
    end

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
          # Leaf node: this is a file (sentinel key "" present)
          meta = file_entry.as(Hash(String, BencodeValue))
          size = meta["length"].as(Int64)
          pieces_root = meta["pieces root"]?.try { |root_bytes| ByteString.new(root_bytes.as(Bytes)) }
          result << TorrentFile.new(path: current_path.join("/"), size: size, pieces_root: pieces_root)
        else
          # Directory node: recurse
          result.concat(collect_file_tree(sub_dict, current_path))
        end
      end
      result
    end

    private def compute_piece_count(info : Hash(String, BencodeValue), version : Int32) : Int64
      if pieces_bytes = info["pieces"]?.try(&.as(Bytes))
        (pieces_bytes.size / 20_i64).to_i64
      else
        total = @files.sum(&.size)
        ((total + @piece_size - 1) / @piece_size).to_i64
      end
    end
  end
end
