module Torinfo
  module Formatters
    # Row-oriented output for --tsv and --csv. Header cells are kebab field
    # tokens. Sizes are byte counts; a `size-<unit>` column is added when a unit
    # was explicitly selected. When files are included each file gets its own row
    # with the torrent's columns repeated.
    class Delimited
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false
      # true => comma-separated with RFC-4180 quoting; false => tab-separated.
      property? csv : Bool = true

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool, header : Bool) : Nil
        ctx = RenderContext.new(unit: @size_unit, visual: false)
        emit_row(io, header_tokens(fields, show_files)) if header
        torrents.each do |torrent|
          scalars = scalar_cells(torrent, fields, ctx)
          if show_files && !torrent.files.empty?
            torrent.files.each { |file| emit_row(io, scalars + file_cells(file)) }
          elsif show_files
            emit_row(io, scalars + Array.new(file_column_count, ""))
          else
            emit_row(io, scalars)
          end
        end
      end

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def header_tokens(fields : Array(Field), show_files : Bool) : Array(String)
        tokens = [] of String
        fields.each do |field|
          if field.size?
            tokens << "size"
            if suffix = companion_suffix
              tokens << "size-#{suffix}"
            end
          else
            tokens << field.token
          end
        end
        if show_files
          tokens << "file-size"
          tokens << "file-size-#{companion_suffix}" if companion_suffix
          tokens << "file-path"
        end
        tokens
      end

      private def scalar_cells(torrent : Torrent, fields : Array(Field), ctx : RenderContext) : Array(String)
        cells = [] of String
        fields.each do |field|
          if field.size?
            cells << torrent.total_size.to_s
            cells << @size_unit.format(torrent.total_size) if companion_suffix
          else
            cells << field.render(torrent, ctx)
          end
        end
        cells
      end

      private def file_cells(file : TorrentFile) : Array(String)
        cells = [file.size.to_s]
        cells << @size_unit.format(file.size) if companion_suffix
        cells << file.path
        cells
      end

      private def file_column_count : Int32
        companion_suffix ? 3 : 2
      end

      private def emit_row(io : IO, cells : Array(String)) : Nil
        io << cells.map { |cell| encode(cell) }.join(delimiter) << '\n'
      end

      private def delimiter : Char
        csv? ? ',' : '\t'
      end

      private def encode(value : String) : String
        if csv?
          value.matches?(/[",\r\n]/) ? %("#{value.gsub('"', "\"\"")}") : value
        else
          value.gsub('\t', "\\t").gsub('\n', "\\n").gsub('\r', "\\r")
        end
      end
    end
  end
end
