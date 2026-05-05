require "base64"

module Torinfo
  struct ByteString
    getter bytes : Bytes

    def initialize(@bytes : Bytes)
    end

    def hex : String
      String.build do |io|
        @bytes.each { |byte| io.printf("%02x", byte) }
      end
    end

    def base64 : String
      Base64.strict_encode(@bytes)
    end

    def ==(other : ByteString) : Bool
      @bytes == other.bytes
    end

    def to_s(io : IO) : Nil
      io << hex
    end
  end
end
