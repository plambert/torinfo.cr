require "json"
require "shell-auto_complete"

module Torinfo
  Shell::AutoComplete.command CLI,
    name: "torinfo",
    description: "tool to read BitTorrent files",
    usage: "torinfo [options] <torrentfile...>",
    footer: "--bashv and --bashf cannot be combined with field specifiers.\n" \
            "--raw is only valid with --text output." do
    # Output format selectors
    flag json : Bool = false, "--json", "Output JSON", negatable: false
    flag text : Bool = false, "--text", "Output human-readable text (DEFAULT)", negatable: false
    flag bashv_prefix : String?, "--bashv PREFIX", "Output bash variable assignments suitable for eval"
    flag bashf_func : String?, "--bashf FUNCTION", "Output bash function call suitable for eval"

    # Output modifiers
    flag raw : Bool = false, "--raw", "Output values only (no labels); only valid with --text", negatable: false
    flag strftime : String?, "--strftime FORMAT", "Format timestamps using strftime-style FORMAT"
    flag unix_epoch : Bool = false, "--unix-epoch", "Format timestamps as seconds since Unix epoch", negatable: false

    # Field selectors
    flag want_name : Bool = false, "--name", "Show the name", negatable: false
    flag want_hash : Bool = false, "--hash", "Show the info hash", negatable: false
    flag want_created_by : Bool = false, "--created-by", "Show the creating program", negatable: false
    flag want_created_on : Bool = false, "--created-on", "Show the creation timestamp", negatable: false
    flag want_comment : Bool = false, "--comment", "Show the comment", negatable: false
    flag want_source : Bool = false, "--source", "Show the source", negatable: false
    flag want_piece_count : Bool = false, "--piece-count", "Show the piece count", negatable: false
    flag want_piece_size : Bool = false, "--piece-size", "Show the piece size", negatable: false
    flag want_total_size : Bool = false, "--total-size", "Show the total size", negatable: false
    flag want_visibility : Bool = false, "--visibility", "Show the visibility", negatable: false
    flag want_trackers : Bool = false, "--trackers", "Show the trackers", negatable: false
    flag want_files : Bool = false, "--files", "List the files", negatable: false

    positionals torrent_paths : Array(Path), "BitTorrent files to read", min: 1

    def run
      emit(STDOUT)
    end

    # Renders the parsed request to *io*. Public so specs can drive it with an
    # in-memory IO; `run` calls it with STDOUT.
    def emit(io : IO) : Nil
      fmt = output_format
      selected = selected_fields
      validate!(fmt, selected)

      torrents = torrent_paths.map { |path| Torrent.from_file(path.to_s) }
      tty = io.is_a?(IO::FileDescriptor) && io.tty?

      case fmt
      when :text
        formatter = Formatters::Text.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.raw = raw
        formatter.format_all(torrents, io, fields: selected)
      when :json
        formatter = Formatters::Json.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.format_all(torrents, io)
      when :bash_vars
        formatter = Formatters::BashVars.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.format_all(torrents, io, prefix: bashv_prefix.to_s, tty: tty)
      when :bash_func
        formatter = Formatters::BashFunc.new
        formatter.time_format = strftime
        formatter.unix_epoch = unix_epoch
        formatter.format_all(torrents, io, func_name: bashf_func.to_s, tty: tty)
      end
    rescue e : IO::Error
      raise e unless e.message =~ %r{Broken pipe}
    end

    # The selected output format, derived from the format-selector flags.
    def output_format : Symbol
      if bashv_prefix
        :bash_vars
      elsif bashf_func
        :bash_func
      elsif json
        :json
      else
        :text
      end
    end

    # The requested field symbols, in display order. Empty means "show all".
    def selected_fields : Array(Symbol)
      fields = [] of Symbol
      fields << :name if want_name
      fields << :hash if want_hash
      fields << :created_by if want_created_by
      fields << :created_on if want_created_on
      fields << :comment if want_comment
      fields << :source if want_source
      fields << :piece_count if want_piece_count
      fields << :piece_size if want_piece_size
      fields << :total_size if want_total_size
      fields << :visibility if want_visibility
      fields << :trackers if want_trackers
      fields << :files if want_files
      fields
    end

    private def validate!(fmt : Symbol, selected : Array(Symbol)) : Nil
      if {:bash_vars, :bash_func}.includes?(fmt) && !selected.empty?
        raise Shell::AutoComplete::ParseError.new("cannot combine --bashv/--bashf with field specifiers")
      end
      if raw && fmt != :text
        raise Shell::AutoComplete::ParseError.new("--raw is only valid with --text output")
      end
    end
  end
end
