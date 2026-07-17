module Torinfo
  module Formatters
    # `eval`-able call to a user function. Argument layout:
    #
    #   funcname <scalar field args in field order> -- <trackers> -- <files>
    #
    # `size` emits a byte count followed by its formatted value when a unit was
    # explicitly selected. The tracker section is present only when the
    # `trackers` field is selected; the file section only with --files, as
    # `path size [size_formatted]` groups. Both `--` separators are always
    # present so the caller can parse the three sections unambiguously.
    class BashFunc
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, func_name : String, tty : Bool, fields : Array(Field), show_files : Bool) : Nil
        torrents.each_with_index do |torrent, index|
          format_one(torrent, io, func_name, tty, fields, show_files)
          io << '\n' if tty && index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, func_name : String, tty : Bool, fields : Array(Field), show_files : Bool) : Nil
        args = build_args(torrent, fields, show_files)
        if tty
          indent = " " * (func_name.size + 1)
          io << func_name << ' ' << args.first << " \\\n"
          args[1...-1].each { |arg| io << indent << arg << " \\\n" }
          io << indent << args.last << '\n'
        else
          io << func_name << ' ' << args.join(' ') << '\n'
        end
      end

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def build_args(torrent : Torrent, fields : Array(Field), show_files : Bool) : Array(String)
        ctx = RenderContext.new(unit: @size_unit, visual: false)
        args = [] of String

        fields.each do |field|
          next if field.trackers?
          if field.size?
            args << torrent.total_size.to_s
            args << bash_quote(@size_unit.format(torrent.total_size)) if companion_suffix
          else
            value = field.render(torrent, ctx)
            args << (unquoted?(field) ? value : bash_quote(value))
          end
        end

        args << "--"
        torrent.trackers.each { |url| args << bash_quote(url) } if fields.includes?(Field::Trackers)

        args << "--"
        if show_files
          torrent.files.each do |file|
            args << bash_quote(file.path)
            args << file.size.to_s
            args << bash_quote(@size_unit.format(file.size)) if companion_suffix
          end
        end

        args
      end

      private def unquoted?(field : Field) : Bool
        field.numeric? || field.format? || field.visibility?
      end

      private def bash_quote(str : String) : String
        "'#{str.gsub("'", "'\\''")}'"
      end
    end
  end
end
