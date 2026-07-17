module Torinfo
  module Formatters
    # `eval`-able bash variable assignments. Variable names are the prefix plus
    # the snake-case field name. Sizes are byte counts; a `size_<unit>` scalar
    # (and per-file `filesize_<unit>` array) is added when a unit was explicitly
    # selected. A self-referential `<prefix>variables` array names every emitted
    # variable, including itself, so callers can `unset "${prefix}variables[@]}"`.
    class BashVars
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, prefix : String, tty : Bool, fields : Array(Field), show_files : Bool) : Nil
        torrents.each_with_index do |torrent, index|
          pfx = effective_prefix(prefix, torrents.size, index)
          format_one(torrent, io, pfx, tty, fields, show_files)
          io << '\n' if tty && index < torrents.size - 1
        end
      end

      def format_one(torrent : Torrent, io : IO, prefix : String, tty : Bool, fields : Array(Field), show_files : Bool) : Nil
        assignments = build_assignments(torrent, prefix, fields, show_files)
        if tty
          assignments.each_with_index do |(var_name, value), index|
            io << (index.zero? ? "#{var_name}=#{value}" : " \\\n  #{var_name}=#{value}")
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

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def build_assignments(torrent : Torrent, prefix : String, fields : Array(Field), show_files : Bool) : Array({String, String})
        ctx = RenderContext.new(unit: @size_unit, visual: false)
        assignments = [] of {String, String}

        fields.each do |field|
          name = "#{prefix}#{field.bash_name}"
          if field.trackers?
            assignments << {name, bash_array(torrent.trackers)}
          else
            value = field.render(torrent, ctx)
            assignments << {name, unquoted?(field) ? value : bash_quote(value)}
            if field.size? && (suffix = companion_suffix)
              assignments << {"#{prefix}size_#{suffix}", bash_quote(@size_unit.format(torrent.total_size))}
            end
          end
        end

        if show_files
          assignments << {"#{prefix}filename", bash_array(torrent.files.map(&.path))}
          assignments << {"#{prefix}filesize", bash_int_array(torrent.files.map(&.size))}
          if suffix = companion_suffix
            formatted = torrent.files.map { |file| @size_unit.format(file.size) }
            assignments << {"#{prefix}filesize_#{suffix}", bash_array(formatted)}
          end
        end

        names = assignments.map { |var_name, _value| var_name }
        names << "#{prefix}variables"
        assignments << {"#{prefix}variables", bash_array(names)}
        assignments
      end

      # Integer and enum-like fields are emitted unquoted.
      private def unquoted?(field : Field) : Bool
        field.numeric? || field.format? || field.visibility?
      end

      private def bash_array(items : Array(String)) : String
        "(#{items.map { |item| bash_quote(item) }.join(' ')})"
      end

      private def bash_int_array(items : Array(Int64)) : String
        "(#{items.map(&.to_s).join(' ')})"
      end
    end
  end
end
