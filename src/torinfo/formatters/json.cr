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
