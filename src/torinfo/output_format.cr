module Torinfo
  # The rendering format selected on the command line.
  enum OutputFormat
    Info
    Table
    Box
    Tsv
    Csv
    Json
    Yaml
    BashVars
    BashFunc

    # Formats that show unit-scaled sizes, `v1`/`hybrid` format labels and honor
    # the --strftime/--unix-epoch timestamp options.
    def visual? : Bool
      info? || table? || box?
    end

    # Column-oriented formats that accept --header/--no-header.
    def tabular? : Bool
      table? || box? || tsv? || csv?
    end

    # Machine-oriented formats keyed by field name.
    def structured? : Bool
      json? || yaml? || bash_vars? || bash_func?
    end

    # Whether --header/--no-header may be specified for this format.
    def header_capable? : Bool
      tabular?
    end

    # The fields shown when the user gives no explicit --fields. Tabular formats
    # default to a compact one-line-per-torrent summary; everything else shows
    # every field (the file listing is separately governed by --files).
    def default_fields : Array(Field)
      if tabular?
        [Field::Size, Field::Visibility, Field::CreatedOn, Field::Name]
      else
        Field.values
      end
    end
  end
end
