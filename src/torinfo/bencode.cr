module Torinfo
  alias BencodeValue = Bytes | Int64 | Array(BencodeValue) | Hash(String, BencodeValue)

  class BencodeParser
    getter raw : Bytes

    @info_range : Range(Int32, Int32)?
    @depth : Int32 = 0

    def initialize(@raw : Bytes)
    end

    def self.parse(bytes : Bytes) : BencodeValue
      new(bytes).parse
    end

    def parse : BencodeValue
      value, _pos = parse_value(0)
      value
    end

    def info_raw_bytes : Bytes?
      return unless range = @info_range
      copy = Bytes.new(range.size)
      @raw[range].copy_to(copy)
      copy
    end

    private def parse_value(pos : Int32) : {BencodeValue, Int32}
      raise ArgumentError.new("empty input at position #{pos}") if pos >= @raw.size
      case @raw[pos].chr
      when 'i'      then parse_int(pos)
      when 'l'      then parse_list(pos)
      when 'd'      then parse_dict(pos)
      when '0'..'9' then parse_string(pos)
      else               raise ArgumentError.new("invalid bencode byte #{@raw[pos]} at position #{pos}")
      end
    end

    private def parse_int(pos : Int32) : {Int64, Int32}
      end_pos = find_byte('e', pos + 1)
      str = String.new(@raw[pos + 1, end_pos - pos - 1])
      {str.to_i64, end_pos + 1}
    end

    private def parse_string(pos : Int32) : {Bytes, Int32}
      colon_pos = find_byte(':', pos)
      len = String.new(@raw[pos, colon_pos - pos]).to_i
      start = colon_pos + 1
      raise ArgumentError.new("string at #{pos} claims length #{len} but only #{@raw.size - start} bytes remain") if start + len > @raw.size
      copy = Bytes.new(len)
      @raw[start, len].copy_to(copy)
      {copy, start + len}
    end

    private def parse_list(pos : Int32) : {Array(BencodeValue), Int32}
      result = [] of BencodeValue
      pos += 1
      while pos < @raw.size && @raw[pos].chr != 'e'
        value, pos = parse_value(pos)
        result << value
      end
      raise ArgumentError.new("unterminated list") if pos >= @raw.size
      {result, pos + 1}
    end

    private def parse_dict(pos : Int32) : {Hash(String, BencodeValue), Int32}
      result = {} of String => BencodeValue
      pos += 1
      @depth += 1
      while pos < @raw.size && @raw[pos].chr != 'e'
        key_bytes, pos = parse_string(pos)
        key = String.new(key_bytes)
        if key == "info" && @depth == 1
          value_start = pos
          value, pos = parse_value(pos)
          @info_range = (value_start...pos)
          result[key] = value
        else
          value, pos = parse_value(pos)
          result[key] = value
        end
      end
      raise ArgumentError.new("unterminated dict") if pos >= @raw.size
      @depth -= 1
      {result, pos + 1}
    end

    private def find_byte(char : Char, from pos : Int32) : Int32
      byte = char.ord.to_u8
      while pos < @raw.size
        return pos if @raw[pos] == byte
        pos += 1
      end
      raise ArgumentError.new("byte '#{char}' not found from position #{pos}")
    end
  end
end
