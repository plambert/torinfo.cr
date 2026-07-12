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

  describe "raw mode" do
    before_each { formatter.raw = true }

    it "omits label for scalar fields" do
      io = IO::Memory.new
      formatter.format_one(torrent, io, fields: [:name])
      expect(io.to_s.chomp).to eq("test-file.txt")
    end

    it "omits label for total_size" do
      io = IO::Memory.new
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      formatter.format_one(torrent, io, fields: [:total_size])
      expect(io.to_s).to match(/\A\d+\n\z/)
    end

    it "omits label for created_on" do
      io = IO::Memory.new
      formatter.format_one(torrent, io, fields: [:created_on])
      expect(io.to_s.chomp).to eq("2024-01-01T00:00:00Z")
    end

    it "outputs one URL per line for trackers" do
      io = IO::Memory.new
      formatter.format_one(torrent, io, fields: [:trackers])
      lines = io.to_s.lines
      expect(lines.first).to match(/\Ahttps?:\/\//)
      expect(lines.none?(&.starts_with?("Trackers:"))).to be_true
    end

    it "outputs size and path per line for files" do
      io = IO::Memory.new
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      formatter.format_one(torrent, io, fields: [:files])
      expect(io.to_s).to match(/\A\d+  /)
      expect(io.to_s).not_to match(/Files:/)
    end

    it "omits ==== headers for multiple torrents" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, fields: [:name])
      expect(io.to_s).not_to match(/====/)
    end
  end

  describe "size units" do
    # v1_single is a single 1024-byte file; v1_multi has 1000, 2000 and 500 byte files.
    let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    def total_size_for(formatter, torrent) : String
      io = IO::Memory.new
      formatter.format_one(torrent, io, fields: [:total_size])
      io.to_s.chomp.sub("Total Size: ", "")
    end

    it "humanizes sizes by default" do
      expect(formatter.size_unit).to eq(Torinfo::SizeUnit::Human)
      expect(total_size_for(formatter, torrent)).to eq(1024_i64.humanize)
    end

    it "shows exact bytes with Bytes" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      expect(total_size_for(formatter, torrent)).to eq("1024")
    end

    it "shows one decimal of kilobytes with Kilobytes" do
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      expect(total_size_for(formatter, torrent)).to eq("1.0")
    end

    it "scales by 1024**2 with Megabytes" do
      formatter.size_unit = Torinfo::SizeUnit::Megabytes
      expect(total_size_for(formatter, multi)).to eq("0.0")
    end

    it "scales by 1024**3 with Gigabytes" do
      formatter.size_unit = Torinfo::SizeUnit::Gigabytes
      expect(total_size_for(formatter, multi)).to eq("0.0")
    end

    it "applies the unit to file sizes too" do
      io = IO::Memory.new
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      formatter.format_one(multi, io, fields: [:files])
      expect(io.to_s).to match(/1\. 1\.0  subdir\/file1\.txt/)
      expect(io.to_s).to match(/3\. 0\.5  other\.txt/)
    end

    it "right-justifies file sizes to the widest size" do
      io = IO::Memory.new
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      formatter.format_one(multi, io, fields: [:files])
      # Widest is "1000"/"2000" (4 chars), so "500" is padded to " 500".
      expect(io.to_s).to match(/  1\. 1000  subdir\/file1\.txt/)
      expect(io.to_s).to match(/  3\.  500  other\.txt/)
    end

    it "aligns the size column across all listed files" do
      io = IO::Memory.new
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      formatter.format_one(multi, io, fields: [:files])
      size_columns = io.to_s.lines.reject(&.starts_with?("Files:")).map(&.index("  ", 5))
      expect(size_columns.uniq.size).to eq(1)
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
