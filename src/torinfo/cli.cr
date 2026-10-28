require "shell-auto_complete"

module Torinfo
  Shell::AutoComplete.command CLI,
    name: "torinfo",
    description: "tool to read BitTorrent files",
    usage: "torinfo [options] <torrentfile...>",
    footer: "Default format is --info for one torrent, --table for several.\n" \
            "--fields takes a comma-separated list and may be repeated; valid fields:\n" \
            "  name format path hash created-by created-on comment source\n" \
            "  piece-count piece-size size visibility trackers\n" \
            "--files/--no-files toggles the file listing independently of --fields." do
    # Output format. One enum flag rather than seven switches: shortcut_flags
    # regenerates --info/--table/--box/--tsv/--csv/--json/--yaml, and --format
    # takes the name directly. BashVars/BashFunc are excluded because they are
    # selected by --bashv/--bashf, which carry a value.
    flag format : OutputFormat?, "--format NAME",
      "Output format: --info, --table, --box, --tsv, --csv, --json, --yaml",
      shortcut_flags: {except: [:bash_vars, :bash_func]}
    flag bashv_prefix : String?, "--bashv PREFIX", "Bash variable assignments for eval"
    flag bashf_func : String?, "--bashf FUNCTION", "Bash function call for eval"

    # Field and file selection. The Field element type drives completion
    # (kebab-cased names, delimiter-aware); transform_with keeps the tailored
    # "unknown field" and "files is not a field" errors.
    flag fields : Array(Field) = [] of Field, "--fields LIST",
      "Comma-separated fields to show (repeatable); replaces the default set",
      delimiter: ",",
      transform_with: :parse_field_token
    flag files : Bool = false, "--files", "Include the per-file listing"

    # Presentation.
    flag header : Bool?, "--header", "Show a header row (default on for table/tsv/csv/box)"
    flag box_charset : BoxCharset = BoxCharset::Auto, "--box-charset MODE",
      "Box glyphs: --utf8, --ascii, or --auto (default) from the locale",
      shortcut_flags: true
    flag size_unit : SizeUnit = SizeUnit::Human, "--size-unit UNIT",
      "Size units: --human (default), --bytes, --kilobytes, --megabytes, --gigabytes",
      shortcut_flags: true
    flag strftime : String?, "--strftime FORMAT", "Format timestamps with strftime FORMAT (visual formats)"
    flag unix_epoch : Bool = false, "--unix-epoch", "Format timestamps as Unix epoch seconds (visual formats)", negatable: false

    positionals torrent_paths : Array(Path), "BitTorrent files to read", min: 1

    # Every spelling that selects a format. Used to keep the "only one output
    # format" rule the seven separate switches used to enforce: the enum flag
    # itself is last-wins, so the occurrence log is what detects a conflict.
    FORMAT_SPELLINGS = %w[--format --info --table --box --tsv --csv --json --yaml]

    def self.parse_field_token(value : String) : Field
      Field.parse_token(value)
    end

    def run
      emit(STDOUT)
    end

    # Renders the parsed request to *io*. Public so specs can drive it with an
    # in-memory IO; `run` calls it with STDOUT.
    def emit(io : IO) : Nil
      fmt = output_format
      fields = resolve_fields(fmt)
      validate!(fmt)

      torrents = torrent_paths.map { |path| Torrent.from_file(path.to_s) }
      tty = io.is_a?(IO::FileDescriptor) && io.tty?
      unit_explicit = flag_given?(:size_unit)
      header_on = header.nil? ? fmt.header_capable? : header != false

      case fmt
      in .info?
        formatter = Formatters::Info.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.size_unit = size_unit
        formatter.format_all(torrents, io, fields, files)
      in .table?, .box?
        formatter = Formatters::Table.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.size_unit = size_unit
        formatter.charset = fmt.box? ? box_charset.resolve(BoxCharset.env_locale) : nil
        formatter.format_all(torrents, io, fields, files, header_on)
      in .tsv?, .csv?
        formatter = Formatters::Delimited.new
        formatter.size_unit = size_unit
        formatter.size_companion = unit_explicit
        formatter.csv = fmt.csv?
        formatter.format_all(torrents, io, fields, files, header_on)
      in .json?
        formatter = Formatters::Json.new
        formatter.size_unit = size_unit
        formatter.size_companion = unit_explicit
        formatter.format_all(torrents, io, fields, files)
      in .yaml?
        formatter = Formatters::Yaml.new
        formatter.size_unit = size_unit
        formatter.size_companion = unit_explicit
        formatter.format_all(torrents, io, fields, files)
      in .bash_vars?
        formatter = Formatters::BashVars.new
        formatter.size_unit = size_unit
        formatter.size_companion = unit_explicit
        formatter.format_all(torrents, io, bashv_prefix.to_s, tty, fields, files)
      in .bash_func?
        formatter = Formatters::BashFunc.new
        formatter.size_unit = size_unit
        formatter.size_companion = unit_explicit
        formatter.format_all(torrents, io, bashf_func.to_s, tty, fields, files)
      end
    rescue e : IO::Error
      raise e unless e.message =~ %r{Broken pipe}
    end

    # The selected format, or the count-dependent default (info for one torrent,
    # table for several). Raises if more than one format flag was given.
    def output_format : OutputFormat
      selected = [] of OutputFormat
      if chosen = format
        selected << chosen
      end
      selected << OutputFormat::BashVars unless bashv_prefix.nil?
      selected << OutputFormat::BashFunc unless bashf_func.nil?
      if formats_requested > 1
        raise Shell::AutoComplete::ParseError.new("only one output format may be given")
      end
      selected.first? || (torrent_paths.size == 1 ? OutputFormat::Info : OutputFormat::Table)
    end

    # How many distinct formats the command line asked for. The enum flag
    # resolves last-wins on its own, so the occurrence log is consulted to keep
    # `--json --yaml` an error rather than silently selecting yaml.
    private def formats_requested : Int32
      spellings = parsed_occurrences.map(&.[0])
      spellings.select! { |spelling| FORMAT_SPELLINGS.includes?(spelling) }
      count = spellings.uniq!.size
      count += 1 unless bashv_prefix.nil?
      count += 1 unless bashf_func.nil?
      count
    end

    # The fields to render: the explicit --fields list (deduped, order preserved)
    # or the format's default set.
    def resolve_fields(fmt : OutputFormat) : Array(Field)
      return fmt.default_fields if fields.empty?
      seen = Set(Field).new
      fields.select { |field| seen.add?(field) }
    end

    private def validate!(fmt : OutputFormat) : Nil
      unless header.nil? || fmt.header_capable?
        raise Shell::AutoComplete::ParseError.new("--header/--no-header is not valid for the #{format_name(fmt)} format")
      end
      if flag_given?(:box_charset) && !fmt.box?
        raise Shell::AutoComplete::ParseError.new("--utf8/--ascii/--box-charset is only valid with --box")
      end
      # These two formats carry a value, so --format cannot select them alone.
      if fmt.bash_vars? && bashv_prefix.nil?
        raise Shell::AutoComplete::ParseError.new("--format bash-vars needs --bashv PREFIX")
      end
      if fmt.bash_func? && bashf_func.nil?
        raise Shell::AutoComplete::ParseError.new("--format bash-func needs --bashf FUNCTION")
      end
    end

    private def format_name(fmt : OutputFormat) : String
      fmt.to_s.underscore.tr("_", "-")
    end
  end
end
