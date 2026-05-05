require "../../spec_helper"

Spectator.describe Torinfo::Formatters::Text do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(formatter) { Torinfo::Formatters::Text.new }

  describe "#format_one" do
    it "includes the torrent name" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Name: test-file\.txt/)
    end

    it "includes the hash with v1 prefix" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Hash: v1 [0-9a-f]{40}/)
    end

    it "includes visibility" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Visibility: public/)
    end

    it "includes numbered trackers" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Trackers:\n  1\. https:\/\/tracker\.example\.com/)
    end

    it "includes numbered files" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Files:\n  1\..*test-file\.txt/)
    end

    it "includes timestamp in RFC 3339 by default" do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 2024-01-01T00:00:00Z/)
    end

    context "with field selection" do
      it "outputs only selected fields" do
        io = IO::Memory.new
        formatter.format_one(torrent, io, fields: [:name, :hash])
        output = io.to_s
        expect(output).to match(/Name:/)
        expect(output).to match(/Hash:/)
        expect(output).not_to match(/Visibility:/)
        expect(output).not_to match(/Trackers:/)
      end
    end
  end

  describe "#format_all" do
    it "adds ==== headers when multiple torrents" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io)
      expect(io.to_s).to match(/====.*v1_single\.torrent.*====/)
      expect(io.to_s).to match(/====.*v1_multi\.torrent.*====/)
    end

    it "omits ==== header for a single torrent" do
      io = IO::Memory.new
      formatter.format_all([torrent], io)
      expect(io.to_s).not_to match(/====/)
    end
  end

  describe "timestamp formatting" do
    it "uses strftime format when provided" do
      io = IO::Memory.new
      formatter.time_format = "%Y-%m-%d"
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 2024-01-01/)
      expect(io.to_s).not_to match(/T00:00:00/)
    end

    it "uses unix epoch when unix_epoch? is true" do
      io = IO::Memory.new
      formatter.unix_epoch = true
      formatter.format_one(torrent, io)
      expect(io.to_s).to match(/Created On: 1704067200/)
    end
  end
end
