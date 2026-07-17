require "../../spec_helper"

Spectator.describe Torinfo::Formatters::Info do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  let(formatter) { Torinfo::Formatters::Info.new }
  let(all_fields) { Torinfo::Field.values }

  def render(formatter, torrent, fields, show_files = false) : String
    io = IO::Memory.new
    formatter.format_one(torrent, io, fields, show_files)
    io.to_s
  end

  describe "#format_one" do
    it "labels each selected field" do
      output = render(formatter, torrent, all_fields)
      expect(output).to match(/Name: test-file\.txt/)
      expect(output).to match(/Format: v1/)
      expect(output).to match(/Hash: v1 [0-9a-f]{40}/)
      expect(output).to match(/Visibility: public/)
      expect(output).to match(/Size: #{Regex.escape(1024_i64.humanize)}/)
    end

    it "renders only the selected fields" do
      output = render(formatter, torrent, [Torinfo::Field::Name, Torinfo::Field::Hash])
      expect(output).to match(/Name:/)
      expect(output).to match(/Hash:/)
      expect(output).not_to match(/Visibility:/)
      expect(output).not_to match(/Size:/)
    end

    it "skips empty optional fields" do
      # source is present ("TEST"); a torrent without a comment would skip it.
      output = render(formatter, torrent, all_fields)
      expect(output).to match(/Source: TEST/)
    end

    it "numbers trackers as a list" do
      output = render(formatter, torrent, [Torinfo::Field::Trackers])
      expect(output).to match(/Trackers:\n  1\. https:\/\/tracker\.example\.com/)
    end

    it "omits files unless requested" do
      expect(render(formatter, torrent, all_fields, show_files: false)).not_to match(/Files:/)
      expect(render(formatter, torrent, all_fields, show_files: true)).to match(/Files:/)
    end

    it "right-justifies file sizes" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      output = render(formatter, multi, [] of Torinfo::Field, show_files: true)
      expect(output).to match(/  1\. 1000  subdir\/file1\.txt/)
      expect(output).to match(/  3\.  500  other\.txt/)
    end

    it "honors the size unit for the size field" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      expect(render(formatter, torrent, [Torinfo::Field::Size])).to eq("Size: 1024\n")
    end
  end

  describe "#format_all" do
    it "adds ==== headers for multiple torrents" do
      io = IO::Memory.new
      formatter.format_all([torrent, multi], io, all_fields, false)
      expect(io.to_s).to match(/====.*v1_single\.torrent.*====/)
      expect(io.to_s).to match(/====.*v1_multi\.torrent.*====/)
    end

    it "omits the header for a single torrent" do
      io = IO::Memory.new
      formatter.format_all([torrent], io, all_fields, false)
      expect(io.to_s).not_to match(/====/)
    end
  end

  describe "timestamp formatting" do
    it "uses strftime when set" do
      formatter.time_format = "%Y-%m-%d"
      expect(render(formatter, torrent, [Torinfo::Field::CreatedOn])).to eq("Created On: 2024-01-01\n")
    end

    it "uses unix epoch when set" do
      formatter.unix_epoch = true
      expect(render(formatter, torrent, [Torinfo::Field::CreatedOn])).to eq("Created On: 1704067200\n")
    end
  end
end
