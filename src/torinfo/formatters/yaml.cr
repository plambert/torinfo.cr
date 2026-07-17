require "yaml"

module Torinfo
  module Formatters
    # One YAML document (`---`) per torrent. Same key/value model as the JSON
    # formatter: kebab keys, byte-integer sizes with an optional `size-<unit>`
    # companion, RFC-3339 `created-on`, and a file list only with --files.
    #
    # String-valued scalars are emitted double-quoted so YAML's implicit typing
    # can't reinterpret a timestamp, "0.0" or "123" as a non-string; numeric
    # fields stay bare so they parse back as numbers.
    class Yaml
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool) : Nil
        torrents.each { |torrent| format_one(torrent, io, fields, show_files) }
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Field), show_files : Bool) : Nil
        YAML.build(io) do |yaml|
          yaml.mapping do
            fields.each { |field| emit_field(yaml, torrent, field) }
            emit_files(yaml, torrent) if show_files
          end
        end
      end

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def emit_field(yaml : YAML::Builder, torrent : Torrent, field : Field) : Nil
        case field
        when .name?        then str_pair(yaml, field.token, torrent.name)
        when .path?        then str_pair(yaml, field.token, torrent.path)
        when .hash?        then str_pair(yaml, field.token, torrent.hash)
        when .visibility?  then str_pair(yaml, field.token, torrent.visibility)
        when .created_by?  then str_pair(yaml, field.token, torrent.created_by)
        when .comment?     then str_pair(yaml, field.token, torrent.comment)
        when .source?      then str_pair(yaml, field.token, torrent.source)
        when .created_on?  then str_pair(yaml, field.token, torrent.created_on.try(&.to_rfc3339))
        when .format?      then num_pair(yaml, field.token, torrent.format_version)
        when .piece_count? then num_pair(yaml, field.token, torrent.piece_count)
        when .piece_size?  then num_pair(yaml, field.token, torrent.piece_size)
        when .trackers?
          yaml.scalar field.token
          yaml.sequence { torrent.trackers.each { |url| yaml.scalar url, style: YAML::ScalarStyle::DOUBLE_QUOTED } }
        when .size?
          num_pair(yaml, field.token, torrent.total_size)
          str_pair(yaml, "size-#{companion_suffix}", @size_unit.format(torrent.total_size)) if companion_suffix
        end
      end

      private def emit_files(yaml : YAML::Builder, torrent : Torrent) : Nil
        suffix = companion_suffix
        yaml.scalar "files"
        yaml.sequence do
          torrent.files.each do |file|
            yaml.mapping do
              str_pair(yaml, "path", file.path)
              num_pair(yaml, "size", file.size)
              str_pair(yaml, "size-#{suffix}", @size_unit.format(file.size)) if suffix
              str_pair(yaml, "pieces-root", file.pieces_root.try(&.hex))
            end
          end
        end
      end

      private def str_pair(yaml : YAML::Builder, key : String, value : String?) : Nil
        yaml.scalar key
        if value
          yaml.scalar value, style: YAML::ScalarStyle::DOUBLE_QUOTED
        else
          yaml.scalar nil
        end
      end

      private def num_pair(yaml : YAML::Builder, key : String, value) : Nil
        yaml.scalar key
        yaml.scalar value
      end
    end
  end
end
