module Torinfo
  struct TorrentFile
    getter path : String
    getter size : Int64
    getter pieces_root : ByteString?

    def initialize(@path : String, @size : Int64, @pieces_root : ByteString? = nil)
    end
  end
end
