module Torinfo
  module Formatters
    # Column-aligned output. With `charset` nil it renders a plain whitespace
    # table; with a resolved Utf8/Ascii charset it draws a bordered box.
    #
    # When files are included they occupy two trailing columns (File Size / File)
    # with one file per row; a torrent with several files spans several rows, the
    # non-file columns left blank on the continuation rows.
    class Table
      record Column, label : String, align : Symbol

      record Glyphs,
        h : String, v : String,
        tl : String, tm : String, tr : String,
        ml : String, mm : String, mr : String,
        bl : String, bm : String, br : String

      UTF8  = Glyphs.new("─", "│", "┌", "┬", "┐", "├", "┼", "┤", "└", "┴", "┘")
      ASCII = Glyphs.new("-", "|", "+", "+", "+", "+", "+", "+", "+", "+", "+")

      property time_format : String?
      property size_unit : SizeUnit = SizeUnit::Human
      property? unix_epoch : Bool = false
      property charset : BoxCharset? = nil

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool, header : Bool) : Nil
        columns = build_columns(fields, show_files)
        ctx = RenderContext.new(
          unit: @size_unit, strftime: @time_format, unix_epoch: @unix_epoch, visual: true
        )
        rows = [] of Array(String)
        torrents.each { |torrent| append_rows(rows, torrent, fields, show_files, ctx) }
        widths = column_widths(columns, rows, header)

        if cs = @charset
          render_box(io, columns, rows, widths, header, glyphs(cs))
        else
          render_plain(io, columns, rows, widths, header)
        end
      end

      private def build_columns(fields : Array(Field), show_files : Bool) : Array(Column)
        columns = fields.map { |field| Column.new(field.label, field.numeric? ? :right : :left) }
        if show_files
          columns << Column.new("File Size", :right)
          columns << Column.new("File", :left)
        end
        columns
      end

      private def append_rows(rows : Array(Array(String)), torrent : Torrent, fields : Array(Field), show_files : Bool, ctx : RenderContext) : Nil
        field_cells = fields.map(&.render(torrent, ctx))
        unless show_files
          rows << field_cells
          return
        end
        if torrent.files.empty?
          rows << field_cells + ["", ""]
          return
        end
        torrent.files.each_with_index do |file, index|
          lead = index.zero? ? field_cells : Array.new(fields.size, "")
          rows << lead + [@size_unit.format(file.size), file.path]
        end
      end

      private def column_widths(columns : Array(Column), rows : Array(Array(String)), header : Bool) : Array(Int32)
        columns.map_with_index do |column, index|
          width = header ? column.label.size : 0
          rows.each { |row| width = Math.max(width, row[index].size) }
          width
        end
      end

      private def pad(cell : String, width : Int32, align : Symbol) : String
        align == :right ? cell.rjust(width) : cell.ljust(width)
      end

      private def render_plain(io : IO, columns : Array(Column), rows : Array(Array(String)), widths : Array(Int32), header : Bool) : Nil
        if header
          io << plain_row(columns.map(&.label), columns, widths) << '\n'
        end
        rows.each { |row| io << plain_row(row, columns, widths) << '\n' }
      end

      private def plain_row(cells : Array(String), columns : Array(Column), widths : Array(Int32)) : String
        cells.map_with_index { |cell, index| pad(cell, widths[index], columns[index].align) }.join("  ").rstrip
      end

      private def render_box(io : IO, columns : Array(Column), rows : Array(Array(String)), widths : Array(Int32), header : Bool, g : Glyphs) : Nil
        io << border(widths, g.tl, g.tm, g.tr, g) << '\n'
        if header
          io << box_row(columns.map(&.label), columns, widths, g) << '\n'
          io << border(widths, g.ml, g.mm, g.mr, g) << '\n'
        end
        rows.each { |row| io << box_row(row, columns, widths, g) << '\n' }
        io << border(widths, g.bl, g.bm, g.br, g) << '\n'
      end

      private def border(widths : Array(Int32), left : String, mid : String, right : String, g : Glyphs) : String
        segments = widths.map { |width| g.h * (width + 2) }
        "#{left}#{segments.join(mid)}#{right}"
      end

      private def box_row(cells : Array(String), columns : Array(Column), widths : Array(Int32), g : Glyphs) : String
        padded = cells.map_with_index { |cell, index| " #{pad(cell, widths[index], columns[index].align)} " }
        "#{g.v}#{padded.join(g.v)}#{g.v}"
      end

      private def glyphs(charset : BoxCharset) : Glyphs
        charset.utf8? ? UTF8 : ASCII
      end
    end
  end
end
