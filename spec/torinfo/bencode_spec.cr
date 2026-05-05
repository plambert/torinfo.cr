require "../spec_helper"

Spectator.describe Torinfo::BencodeParser do
  describe ".parse" do
    context "integers" do
      it "parses a positive integer" do
        result = Torinfo::BencodeParser.parse("i42e".to_slice)
        expect(result).to be_a(Int64)
        expect(result.as(Int64)).to eq(42_i64)
      end

      it "parses a negative integer" do
        result = Torinfo::BencodeParser.parse("i-7e".to_slice)
        expect(result.as(Int64)).to eq(-7_i64)
      end

      it "parses zero" do
        result = Torinfo::BencodeParser.parse("i0e".to_slice)
        expect(result.as(Int64)).to eq(0_i64)
      end
    end

    context "byte strings" do
      it "parses a byte string" do
        result = Torinfo::BencodeParser.parse("4:spam".to_slice)
        expect(result).to be_a(Bytes)
        expect(String.new(result.as(Bytes))).to eq("spam")
      end

      it "parses an empty byte string" do
        result = Torinfo::BencodeParser.parse("0:".to_slice)
        expect(result.as(Bytes).size).to eq(0)
      end

      it "parses binary data (non-UTF-8)" do
        raw = Bytes[0x33, 0x3a, 0xde, 0xad, 0xbe] # "3:\xde\xad\xbe"
        result = Torinfo::BencodeParser.parse(raw)
        expect(result.as(Bytes)).to eq(Bytes[0xde, 0xad, 0xbe])
      end
    end

    context "lists" do
      it "parses an empty list" do
        result = Torinfo::BencodeParser.parse("le".to_slice)
        expect(result).to be_a(Array(Torinfo::BencodeValue))
        expect(result.as(Array(Torinfo::BencodeValue)).size).to eq(0)
      end

      it "parses a list of integers" do
        result = Torinfo::BencodeParser.parse("li1ei2ei3ee".to_slice)
        list = result.as(Array(Torinfo::BencodeValue))
        expect(list.size).to eq(3)
        expect(list[0].as(Int64)).to eq(1_i64)
        expect(list[2].as(Int64)).to eq(3_i64)
      end

      it "parses a list of strings" do
        result = Torinfo::BencodeParser.parse("l4:spam4:eggse".to_slice)
        list = result.as(Array(Torinfo::BencodeValue))
        expect(String.new(list[0].as(Bytes))).to eq("spam")
        expect(String.new(list[1].as(Bytes))).to eq("eggs")
      end

      it "parses a nested list" do
        result = Torinfo::BencodeParser.parse("lli1eeli2eee".to_slice)
        outer = result.as(Array(Torinfo::BencodeValue))
        expect(outer.size).to eq(2)
        inner = outer[0].as(Array(Torinfo::BencodeValue))
        expect(inner[0].as(Int64)).to eq(1_i64)
      end
    end

    context "dictionaries" do
      it "parses an empty dict" do
        result = Torinfo::BencodeParser.parse("de".to_slice)
        expect(result).to be_a(Hash(String, Torinfo::BencodeValue))
        expect(result.as(Hash(String, Torinfo::BencodeValue)).size).to eq(0)
      end

      it "parses a simple dict" do
        result = Torinfo::BencodeParser.parse("d3:cow3:moo4:spam4:eggse".to_slice)
        dict = result.as(Hash(String, Torinfo::BencodeValue))
        expect(String.new(dict["cow"].as(Bytes))).to eq("moo")
        expect(String.new(dict["spam"].as(Bytes))).to eq("eggs")
      end

      it "parses a nested dict" do
        result = Torinfo::BencodeParser.parse("d4:infod4:name4:testee".to_slice)
        outer = result.as(Hash(String, Torinfo::BencodeValue))
        inner = outer["info"].as(Hash(String, Torinfo::BencodeValue))
        expect(String.new(inner["name"].as(Bytes))).to eq("test")
      end
    end

    context "errors" do
      it "raises on unknown type byte" do
        expect { Torinfo::BencodeParser.parse("x".to_slice) }.to raise_error(ArgumentError, /invalid/i)
      end

      it "raises on unterminated integer" do
        expect { Torinfo::BencodeParser.parse("i42".to_slice) }.to raise_error(ArgumentError)
      end

      it "raises on truncated string" do
        expect { Torinfo::BencodeParser.parse("5:hi".to_slice) }.to raise_error(ArgumentError)
      end
    end
  end

  describe "#info_raw_bytes" do
    it "returns nil when no info key present" do
      parser = Torinfo::BencodeParser.new("d3:foo3:bare".to_slice)
      parser.parse
      expect(parser.info_raw_bytes).to be_nil
    end

    it "returns raw bytes of the info value" do
      raw = "d4:infod4:name4:teste3:foo3:bare".to_slice
      parser = Torinfo::BencodeParser.new(raw)
      parser.parse
      info_bytes = parser.info_raw_bytes
      expect(info_bytes).not_to be_nil
      reparsed = Torinfo::BencodeParser.parse(info_bytes.not_nil!) # ameba:disable Lint/NotNil
      dict = reparsed.as(Hash(String, Torinfo::BencodeValue))
      expect(String.new(dict["name"].as(Bytes))).to eq("test")
    end
  end
end
