require "../spec_helper"

Spectator.describe Torinfo::ByteString do
  let(bytes) { Bytes[0xde, 0xad, 0xbe, 0xef] }
  subject(bs) { Torinfo::ByteString.new(bytes) }

  describe "#bytes" do
    it "returns the wrapped bytes" do
      expect(bs.bytes).to eq(bytes)
    end
  end

  describe "#hex" do
    it "returns lowercase hex string" do
      expect(bs.hex).to eq("deadbeef")
    end

    it "zero-pads single-digit bytes" do
      single = Torinfo::ByteString.new(Bytes[0x0f])
      expect(single.hex).to eq("0f")
    end
  end

  describe "#base64" do
    it "returns strict base64 encoding" do
      expect(bs.base64).to eq("3q2+7w==")
    end
  end

  describe "#to_s" do
    it "renders as hex" do
      expect(bs.to_s).to eq("deadbeef")
    end
  end

  describe "#==" do
    it "equals another ByteString with same bytes" do
      expect(bs).to eq(Torinfo::ByteString.new(Bytes[0xde, 0xad, 0xbe, 0xef]))
    end

    it "does not equal a ByteString with different bytes" do
      expect(bs).not_to eq(Torinfo::ByteString.new(Bytes[0x00]))
    end
  end
end
