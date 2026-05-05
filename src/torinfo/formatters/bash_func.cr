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
        time_str = format_time(torrent.created_on)

        args = [
          bash_quote(torrent.path),
          bash_quote(torrent.name),
          bash_quote(torrent.hash),
          bash_quote(torrent.created_by || ""),
          bash_quote(time_str),
          bash_quote(torrent.comment || ""),
          bash_quote(torrent.source || ""),
          torrent.piece_count.to_s,
          torrent.piece_size.to_s,
          torrent.total_size.to_s,
          torrent.visibility,
          torrent.format_version.to_s,
        ]

        torrent.trackers.each { |url| args << bash_quote(url) }
        args << "--"
        torrent.files.each { |file| args << bash_quote(file.path) << file.size.to_s }

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
