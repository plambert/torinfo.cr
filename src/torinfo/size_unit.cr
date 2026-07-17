module Torinfo
  # How byte counts are rendered in human-facing output.
  enum SizeUnit
    # Metric-suffixed short form via `Int#humanize` (e.g. "1.02k").
    Human
    # Exact byte count.
    Bytes
    # Binary-scaled (1024**N) with one decimal place.
    Kilobytes
    Megabytes
    Gigabytes

    # Renders *size* bytes in this unit.
    def format(size : Int) : String
      case self
      in Human     then size.humanize
      in Bytes     then size.to_s
      in Kilobytes then scale(size, 1024_i64)
      in Megabytes then scale(size, 1024_i64 ** 2)
      in Gigabytes then scale(size, 1024_i64 ** 3)
      end
    end

    # Whether this unit renders exact integer bytes.
    def bytes? : Bool
      self == Bytes
    end

    # Suffix appended to a companion field name in structured output (e.g.
    # `size_gb`). `nil` for Bytes, whose value is the base field itself.
    def suffix : String?
      case self
      in Bytes     then nil
      in Human     then "human"
      in Kilobytes then "kb"
      in Megabytes then "mb"
      in Gigabytes then "gb"
      end
    end

    private def scale(size : Int, divisor : Int64) : String
      "%.1f" % (size.to_f64 / divisor)
    end
  end
end
