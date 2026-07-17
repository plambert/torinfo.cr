module Torinfo
  # Per-render options shared by the formatters: which size unit to use, how to
  # format timestamps, and whether the target format is "visual" (info/table/box,
  # which show unit-scaled sizes, `v1`/`hybrid` format labels and honor the
  # timestamp options) or flat/structured (which show byte counts, numeric format
  # versions and a fixed RFC-3339 timestamp).
  struct RenderContext
    getter unit : SizeUnit
    getter strftime : String?
    getter? unix_epoch : Bool
    getter? visual : Bool

    def initialize(@unit : SizeUnit = SizeUnit::Human, @strftime : String? = nil,
                   @unix_epoch : Bool = false, @visual : Bool = false)
    end

    # Formats a timestamp for visual output, honoring --unix-epoch/--strftime.
    def visual_time(time : Time) : String
      if unix_epoch?
        time.to_unix.to_s
      elsif fmt = @strftime
        time.to_s(fmt)
      else
        time.to_rfc3339
      end
    end
  end

  # A selectable torrent metadata field. The order of declaration is the
  # canonical output order used whenever fields aren't explicitly ordered.
  #
  # `files` is intentionally NOT a field: the file listing is controlled by the
  # independent `--files`/`--no-files` switch.
  enum Field
    Name
    Format
    Path
    Hash
    CreatedBy
    CreatedOn
    Comment
    Source
    PieceCount
    PieceSize
    Size
    Visibility
    Trackers

    # Kebab-case CLI token and json/yaml/tsv/csv key, e.g. `created-on`.
    def token : String
      to_s.underscore.tr("_", "-")
    end

    # Snake-case identifier for bash variable names, e.g. `created_on`.
    def bash_name : String
      to_s.underscore
    end

    # Title-cased human label for table/box headers, e.g. `Created On`.
    def label : String
      to_s.underscore.split('_').join(' ', &.capitalize)
    end

    # Whether this field holds multiple values (rendered as an array in
    # json/yaml/bash and joined with "; " in tabular text).
    def multi_value? : Bool
      self == Trackers
    end

    # Whether the field's value is an integer, so tabular formats right-justify
    # its column.
    def numeric? : Bool
      case self
      when Size, PieceCount, PieceSize then true
      else                                  false
      end
    end

    # The field's value rendered as a single display string for the given
    # context. Trackers are joined with "; "; callers that need the array
    # (json/yaml/bash) read `torrent.trackers` directly.
    def render(torrent : Torrent, ctx : RenderContext) : String
      case self
      in Name       then torrent.name
      in Path       then torrent.path
      in Hash       then torrent.hash
      in Visibility then torrent.visibility
      in CreatedBy  then torrent.created_by || ""
      in Comment    then torrent.comment || ""
      in Source     then torrent.source || ""
      in PieceCount then torrent.piece_count.to_s
      in PieceSize  then torrent.piece_size.to_s
      in Format     then ctx.visual? ? Field.format_label(torrent.format_version) : torrent.format_version.to_s
      in Size       then ctx.visual? ? ctx.unit.format(torrent.total_size) : torrent.total_size.to_s
      in CreatedOn  then Field.render_time(torrent.created_on, ctx)
      in Trackers   then torrent.trackers.join("; ")
      end
    end

    # The `format` field's visual label.
    def self.format_label(version : Int32) : String
      case version
      when 1 then "v1"
      when 2 then "v2"
      when 3 then "hybrid"
      else        "unknown"
      end
    end

    # Visual output honors --unix-epoch/--strftime; flat/structured output uses a
    # fixed RFC-3339 rendering.
    def self.render_time(time : Time?, ctx : RenderContext) : String
      return "" unless time
      ctx.visual? ? ctx.visual_time(time) : time.to_rfc3339
    end

    # Parses a kebab token into a Field, raising ArgumentError on an unknown or
    # reserved token. `files` is reserved for the --files switch.
    def self.parse_token(token : String) : Field
      if token == "files"
        raise ArgumentError.new("field 'files' is controlled by --files/--no-files, not --fields")
      end
      values.find { |field| field.token == token } ||
        raise ArgumentError.new("unknown field: #{token} (valid: #{values.map(&.token).join(", ")})")
    end
  end
end
