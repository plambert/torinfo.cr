module Torinfo
  module Formatters
    class Text
      property time_format : String?
      property? unix_epoch : Bool = false
      property? raw : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Symbol) = [] of Symbol) : Nil
        torrents.each_with_index do |torrent, index|
          io << "==== #{torrent.path} ====\n" if torrents.size > 1 && !@raw
          format_one(torrent, io, fields: fields)
          io << '\n' if index < torrents.size - 1 && !@raw
        end
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Symbol) = [] of Symbol) : Nil
        show_all = fields.empty?

        emit_scalar_fields(io, torrent, show_all, fields)
        emit_trackers(io, torrent) if show_all || fields.includes?(:trackers)
        emit_files(io, torrent) if show_all || fields.includes?(:files)
      end

      private def emit_scalar_fields(io : IO, torrent : Torrent, show_all : Bool, fields : Array(Symbol)) : Nil
        emit(io, "Name", torrent.name) if show_all || fields.includes?(:name)
        emit(io, "Format", format_version_label(torrent.format_version)) if show_all
        emit(io, "Hash", torrent.hash) if show_all || fields.includes?(:hash)
        emit(io, "Created By", torrent.created_by) if show_all || fields.includes?(:created_by)
        emit_time(io, "Created On", torrent.created_on) if show_all || fields.includes?(:created_on)
        emit(io, "Comment", torrent.comment) if show_all || fields.includes?(:comment)
        emit(io, "Source", torrent.source) if show_all || fields.includes?(:source)
        emit_stat_fields(io, torrent, show_all, fields)
        emit(io, "Visibility", torrent.visibility) if show_all || fields.includes?(:visibility)
      end

      private def emit_stat_fields(io : IO, torrent : Torrent, show_all : Bool, fields : Array(Symbol)) : Nil
        emit(io, "Piece Count", torrent.piece_count.to_s) if show_all || fields.includes?(:piece_count)
        emit(io, "Piece Size", torrent.piece_size.to_s) if show_all || fields.includes?(:piece_size)
        emit(io, "Total Size", torrent.total_size.to_s) if show_all || fields.includes?(:total_size)
      end

      private def emit_trackers(io : IO, torrent : Torrent) : Nil
        return if torrent.trackers.empty?
        if @raw
          torrent.trackers.each { |url| io << url << '\n' }
        else
          io << "Trackers:\n"
          torrent.trackers.each_with_index(offset: 1) { |url, num| io << "  #{num}. #{url}\n" }
        end
      end

      private def emit_files(io : IO, torrent : Torrent) : Nil
        return if torrent.files.empty?
        if @raw
          torrent.files.each { |file| io << file.size << "  " << file.path << '\n' }
        else
          io << "Files:\n"
          torrent.files.each_with_index(offset: 1) { |file, num| io << "  #{num}. #{file.size}  #{file.path}\n" }
        end
      end

      private def emit(io : IO, label : String, value : String?) : Nil
        return if value.nil? || value.empty?
        if @raw
          io << value << '\n'
        else
          io << "#{label}: #{value}\n"
        end
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
        if @raw
          io << formatted << '\n'
        else
          io << "#{label}: #{formatted}\n"
        end
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
