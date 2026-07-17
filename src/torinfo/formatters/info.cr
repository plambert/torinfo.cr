module Torinfo
  module Formatters
    # Human-readable, labelled output (the default for a single torrent).
    class Info
      property time_format : String?
      property size_unit : SizeUnit = SizeUnit::Human
      property? unix_epoch : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool) : Nil
        torrents.each_with_index do |torrent, index|
          io << "==== #{torrent.path} ====\n" if torrents.size > 1
          format_one(torrent, io, fields, show_files)
          io << '\n' if index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Field), show_files : Bool) : Nil
        ctx = RenderContext.new(
          unit: @size_unit, strftime: @time_format, unix_epoch: @unix_epoch, visual: true
        )
        fields.each do |field|
          if field.multi_value?
            emit_trackers(io, torrent) if field.trackers?
          else
            value = field.render(torrent, ctx)
            io << "#{field.label}: #{value}\n" unless value.empty?
          end
        end
        emit_files(io, torrent) if show_files
      end

      private def emit_trackers(io : IO, torrent : Torrent) : Nil
        return if torrent.trackers.empty?
        io << "Trackers:\n"
        torrent.trackers.each_with_index(offset: 1) { |url, num| io << "  #{num}. #{url}\n" }
      end

      private def emit_files(io : IO, torrent : Torrent) : Nil
        return if torrent.files.empty?
        sizes = torrent.files.map { |file| @size_unit.format(file.size) }
        width = sizes.max_of(&.size)
        io << "Files:\n"
        torrent.files.each_with_index do |file, index|
          io << "  #{index + 1}. #{sizes[index].rjust(width)}  #{file.path}\n"
        end
      end
    end
  end
end
