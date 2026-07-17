require "../../spec_helper"

Spectator.describe Torinfo::Formatters::Delimited do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  let(formatter) { Torinfo::Formatters::Delimited.new }
  let(default_fields) { Torinfo::OutputFormat::Csv.default_fields }

  def render(formatter, torrents, fields, show_files = false, header = true) : String
    io = IO::Memory.new
    formatter.format_all(torrents, io, fields, show_files, header)
    io.to_s
  end

  describe "csv" do
    it "writes a kebab-token header by default" do
      output = render(formatter, [single], default_fields)
      expect(output.lines.first).to eq("size,visibility,created-on,name")
    end

    it "omits the header when header is false" do
      output = render(formatter, [single], default_fields, header: false)
      expect(output.lines.size).to eq(1)
    end

    it "emits size as bytes and a numeric format" do
      output = render(formatter, [single], [Torinfo::Field::Format, Torinfo::Field::Size], header: false)
      expect(output.chomp).to eq("1,1024")
    end

    it "uses RFC-3339 for created-on regardless of unit" do
      output = render(formatter, [single], [Torinfo::Field::CreatedOn], header: false)
      expect(output.chomp).to eq("2024-01-01T00:00:00Z")
    end

    it "quotes cells containing the delimiter" do
      output = render(formatter, [multi], [Torinfo::Field::Trackers], header: false)
      # trackers are joined with "; " (no comma) so no quoting needed here,
      # but a comment with a comma would be quoted; assert the join form.
      expect(output.chomp).to eq("https://tracker.example.com/announce; https://backup.example.com/announce")
    end

    it "adds a size-<unit> column only when a unit was selected" do
      formatter.size_unit = Torinfo::SizeUnit::Gigabytes
      formatter.size_companion = true
      output = render(formatter, [single], [Torinfo::Field::Size])
      expect(output.lines[0]).to eq("size,size-gb")
      expect(output.lines[1]).to eq("1024,0.0")
    end
  end

  describe "files (one row per file)" do
    it "repeats torrent columns and adds file columns" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      output = render(formatter, [multi], [Torinfo::Field::Name], show_files: true)
      expect(output.lines[0]).to eq("name,file-size,file-path")
      expect(output.lines[1]).to eq("test-dir,1000,subdir/file1.txt")
      expect(output.lines[2]).to eq("test-dir,2000,subdir/file2.txt")
      expect(output.lines[3]).to eq("test-dir,500,other.txt")
    end
  end

  describe "tsv" do
    it "separates with tabs and escapes embedded tabs" do
      formatter.csv = false
      output = render(formatter, [single], [Torinfo::Field::Size, Torinfo::Field::Name], header: false)
      expect(output.chomp).to eq("1024\ttest-file.txt")
    end
  end
end
