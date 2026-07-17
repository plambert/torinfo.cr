require "json"

module Torinfo
  module Formatters
    # NDJSON: one object per torrent. Keys are kebab field tokens. Sizes are byte
    # integers; a `size-<unit>` string is added when a unit was explicitly
    # selected. `created-on` is always RFC-3339. The file list appears only with
    # --files.
    class Json
      property size_unit : SizeUnit = SizeUnit::Human
      property? size_companion : Bool = false

      def format_all(torrents : Array(Torrent), io : IO, fields : Array(Field), show_files : Bool) : Nil
        torrents.each { |torrent| format_one(torrent, io, fields, show_files) }
      end

      def format_one(torrent : Torrent, io : IO, fields : Array(Field), show_files : Bool) : Nil
        JSON.build(io) do |json|
          json.object do
            fields.each { |field| emit_field(json, torrent, field) }
            emit_files(json, torrent) if show_files
          end
        end
        io << '\n'
      end

      private def companion_suffix : String?
        size_companion? ? @size_unit.suffix : nil
      end

      private def emit_field(json : JSON::Builder, torrent : Torrent, field : Field) : Nil
        case field
        when .name?        then json.field field.token, torrent.name
        when .path?        then json.field field.token, torrent.path
        when .hash?        then json.field field.token, torrent.hash
        when .visibility?  then json.field field.token, torrent.visibility
        when .created_by?  then json.field field.token, torrent.created_by
        when .comment?     then json.field field.token, torrent.comment
        when .source?      then json.field field.token, torrent.source
        when .format?      then json.field field.token, torrent.format_version
        when .piece_count? then json.field field.token, torrent.piece_count
        when .piece_size?  then json.field field.token, torrent.piece_size
        when .created_on?  then json.field field.token, torrent.created_on.try(&.to_rfc3339)
        when .trackers?    then json.field field.token, torrent.trackers
        when .size?
          json.field field.token, torrent.total_size
          if suffix = companion_suffix
            json.field "size-#{suffix}", @size_unit.format(torrent.total_size)
          end
        end
      end

      private def emit_files(json : JSON::Builder, torrent : Torrent) : Nil
        suffix = companion_suffix
        json.field "files" do
          json.array do
            torrent.files.each do |file|
              json.object do
                json.field "path", file.path
                json.field "size", file.size
                json.field "size-#{suffix}", @size_unit.format(file.size) if suffix
                json.field "pieces-root", file.pieces_root.try(&.hex)
              end
            end
          end
        end
      end
    end
  end
end
