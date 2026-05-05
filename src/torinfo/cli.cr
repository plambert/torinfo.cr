require "json"

module Torinfo
  HELP = <<-HELP
    torinfo - tool to read BitTorrent files

    Usage: torinfo [options] <torrentfile...>

    Options

      --help, -h                      Show this help

      --files                         List the files
      --name, --hash, --created-by,
      --created-on, --comment,
      --source, --piece-count,
      --piece-size, --total-size,
      --visibility, --trackers        Show one or more fields

      --text                          Output values as human-readable text (DEFAULT)
      --bashv PREFIX                  Output bash variable assignments suitable for eval
      --bashf FUNCTION                Output bash function call suitable for eval
      --json                          Output JSON

      --strftime FORMAT               Format timestamps using strftime-style FORMAT
      --unix-epoch                    Format timestamps as seconds since Unix epoch

    Notes:
      --bashv and --bashf cannot be combined with field specifiers.
    HELP

  FIELD_FLAGS = {
    "--name"        => :name,
    "--hash"        => :hash,
    "--created-by"  => :created_by,
    "--created-on"  => :created_on,
    "--comment"     => :comment,
    "--source"      => :source,
    "--piece-count" => :piece_count,
    "--piece-size"  => :piece_size,
    "--total-size"  => :total_size,
    "--visibility"  => :visibility,
    "--trackers"    => :trackers,
    "--files"       => :files,
  }

  class CLI
    getter output_format : Symbol = :text
    getter bash_prefix : String = ""
    getter bash_func_name : String = ""
    getter fields : Array(Symbol) = [] of Symbol
    getter time_format : String?
    getter? unix_epoch : Bool = false
    getter torrent_paths : Array(String) = [] of String

    def initialize(opts = ARGV.dup)
      while opt = opts.shift?
        case opt
        when "--help", "-h"
          puts HELP
          exit 0
        when "--text"
          @output_format = :text
        when "--json"
          @output_format = :json
        when "--bashv"
          @output_format = :bash_vars
          @bash_prefix = opts.shift? || raise ArgumentError.new("--bashv requires a PREFIX argument")
        when "--bashf"
          @output_format = :bash_func
          @bash_func_name = opts.shift? || raise ArgumentError.new("--bashf requires a FUNCTION argument")
        when "--strftime"
          @time_format = opts.shift? || raise ArgumentError.new("--strftime requires a FORMAT argument")
        when "--unix-epoch"
          @unix_epoch = true
        when "--name", "--hash", "--created-by", "--created-on", "--comment",
             "--source", "--piece-count", "--piece-size", "--total-size",
             "--visibility", "--trackers", "--files"
          @fields << FIELD_FLAGS[opt]
        when /\A--/
          raise ArgumentError.new("#{opt}: unknown option")
        else
          @torrent_paths << opt
        end
      end

      if [:bash_vars, :bash_func].includes?(@output_format) && !@fields.empty?
        raise ArgumentError.new("cannot combine --bashv/--bashf with field specifiers")
      end
    end

    def run(io : IO = STDOUT) : Nil
      torrents = @torrent_paths.map { |path| Torrent.from_file(path) }
      tty = io.is_a?(IO::FileDescriptor) && io.tty?

      case @output_format
      when :text
        fmt = Formatters::Text.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, fields: @fields)
      when :json
        fmt = Formatters::Json.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io)
      when :bash_vars
        fmt = Formatters::BashVars.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, prefix: @bash_prefix, tty: tty)
      when :bash_func
        fmt = Formatters::BashFunc.new
        fmt.time_format = @time_format
        fmt.unix_epoch = @unix_epoch
        fmt.format_all(torrents, io, func_name: @bash_func_name, tty: tty)
      end
    end
  end
end
