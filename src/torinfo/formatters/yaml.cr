module Torinfo
  module Formatters
    # One YAML document (`---`) per torrent. Same key/value model as the JSON
    # formatter: kebab keys, byte-integer sizes with an optional `size-<unit>`
    # companion, RFC-3339 `created-on`, and a file list only with --files.
    #
    # The YAML is emitted by hand rather than through Crystal's `yaml` stdlib so
    # the binary does not link libyaml. String scalars are double-quoted (so a
    # timestamp, "0.0" or "123" can't be reinterpreted as a non-string); numeric
    # fields are bare so they parse back as numbers; nil is an empty (null) value.
    class Yaml
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool) : Nil
        torrents.each { |torrent| format_one(torrent, io, fields, show_files) }
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Field), show_files : Bool) : Nil
        io << "---\n"
        fields.each { |field| emit_field(io, torrent, field) }
        emit_files(io, torrent) if show_files
      end

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def emit_field(io : IO, torrent : Torrent, field : Field) : Nil
        case field
        when .name?        then str(io, "", field.token, torrent.name)
        when .path?        then str(io, "", field.token, torrent.path)
        when .hash?        then str(io, "", field.token, torrent.hash)
        when .visibility?  then str(io, "", field.token, torrent.visibility)
        when .created_by?  then str(io, "", field.token, torrent.created_by)
        when .comment?     then str(io, "", field.token, torrent.comment)
        when .source?      then str(io, "", field.token, torrent.source)
        when .created_on?  then str(io, "", field.token, torrent.created_on.try(&.to_rfc3339))
        when .format?      then num(io, "", field.token, torrent.format_version)
        when .piece_count? then num(io, "", field.token, torrent.piece_count)
        when .piece_size?  then num(io, "", field.token, torrent.piece_size)
        when .trackers?    then seq(io, field.token, torrent.trackers)
        when .size?
          num(io, "", field.token, torrent.total_size)
          str(io, "", "size-#{companion_suffix}", @size_unit.format(torrent.total_size)) if companion_suffix
        end
      end

      private def emit_files(io : IO, torrent : Torrent) : Nil
        suffix = companion_suffix
        if torrent.files.empty?
          io << "files: []\n"
          return
        end
        io << "files:\n"
        torrent.files.each do |file|
          io << "- "
          io << "path: " << yaml_quote(file.path) << '\n'
          num(io, "  ", "size", file.size)
          str(io, "  ", "size-#{suffix}", @size_unit.format(file.size)) if suffix
          str(io, "  ", "pieces-root", file.pieces_root.try(&.hex))
        end
      end

      # A `key: "value"` line; a nil value becomes `key:` (YAML null).
      private def str(io : IO, indent : String, key : String, value : String?) : Nil
        io << indent << key << ':'
        io << ' ' << yaml_quote(value) if value
        io << '\n'
      end

      # A `key: value` line for bare numeric scalars.
      private def num(io : IO, indent : String, key : String, value) : Nil
        io << indent << key << ": " << value << '\n'
      end

      # A `key:` block sequence of double-quoted scalars (or `key: []` if empty).
      private def seq(io : IO, key : String, values : Array(String)) : Nil
        if values.empty?
          io << key << ": []\n"
          return
        end
        io << key << ":\n"
        values.each { |value| io << "- " << yaml_quote(value) << '\n' }
      end

      private def yaml_quote(str : String) : String
        escaped = str.gsub('\\', "\\\\").gsub('"', "\\\"")
          .gsub('\n', "\\n").gsub('\t', "\\t").gsub('\r', "\\r")
        %("#{escaped}")
      end
    end
  end
end
