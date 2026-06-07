module Torinfo
  module Formatters
    class BashVars
      property time_format : String?
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, prefix : String, tty : Bool) : Nil
        torrents.each_with_index do |torrent, index|
          pfx = effective_prefix(prefix, torrents.size, index)
          format_one(torrent, io, prefix: pfx, tty: tty)
          io << '\n' if tty && index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, prefix : String, tty : Bool) : Nil
        assignments = build_assignments(torrent, prefix)
        if tty
          assignments.each_with_index do |pair, index|
            var_name, value = pair
            if index == 0
              io << "#{var_name}=#{value}"
            else
              io << " \\\n  #{var_name}=#{value}"
            end
          end
          io << '\n'
        else
          io << assignments.map { |var_name, value| "#{var_name}=#{value}" }.join(' ') << '\n'
        end
      end

      def bash_quote(str : String) : String
        "'#{str.gsub("'", "'\\''")}'"
      end

      private def effective_prefix(prefix : String, count : Int32, index : Int32) : String
        return prefix if count == 1
        if prefix =~ /\A.*%0*\d*d.*\z/
          prefix % (index + 1)
        else
          "#{prefix}#{index + 1}_"
        end
      end

      private def build_assignments(torrent : Torrent, prefix : String) : Array({String, String})
        time_str = format_time(torrent.created_on)
        assignments = [
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
        names = assignments.map { |var_name, _value| var_name }
        names << "#{prefix}variables"
        assignments << {"#{prefix}variables", bash_array(names)}
        assignments
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
