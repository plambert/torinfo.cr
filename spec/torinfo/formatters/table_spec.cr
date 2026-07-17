require "../../spec_helper"

Spectator.describe Torinfo::Formatters::Table do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  let(formatter) { Torinfo::Formatters::Table.new }
  let(default_fields) { Torinfo::OutputFormat::Table.default_fields }

  def render(formatter, torrents, fields, show_files = false, header = true) : String
    io = IO::Memory.new
    formatter.format_all(torrents, io, fields, show_files, header)
    io.to_s
  end

  describe "plain table" do
    it "prints a Title-Case header row by default" do
      output = render(formatter, [single, multi], default_fields)
      lines = output.lines
      expect(lines.first).to match(/Size\s+Visibility\s+Created On\s+Name/)
    end

    it "omits the header when header is false" do
      output = render(formatter, [single], default_fields, header: false)
      expect(output).not_to match(/Visibility/)
    end

    it "puts one torrent per line when files are excluded" do
      output = render(formatter, [single, multi], default_fields)
      body = output.lines[1..]
      expect(body.size).to eq(2)
      expect(body[0]).to match(/test-file\.txt/)
      expect(body[1]).to match(/test-dir/)
    end

    it "right-justifies the size column" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      output = render(formatter, [single, multi], [Torinfo::Field::Size, Torinfo::Field::Name])
      # 1024 and 3500 -> width 4; the single torrent's 1024 sits under the header.
      expect(output).to match(/^1024  /m)
      expect(output).to match(/^3500  /m)
    end

    it "joins trackers with a semicolon in one cell" do
      output = render(formatter, [multi], [Torinfo::Field::Trackers, Torinfo::Field::Name])
      expect(output).to match(/tracker\.example\.com\/announce; https:\/\/backup\.example\.com\/announce/)
    end
  end

  describe "files as two columns" do
    it "adds File Size and File header columns" do
      output = render(formatter, [multi], default_fields, show_files: true)
      expect(output.lines.first).to match(/File Size\s+File$/)
    end

    it "uses one row per file with blank lead columns on continuation rows" do
      formatter.size_unit = Torinfo::SizeUnit::Bytes
      output = render(formatter, [multi], [Torinfo::Field::Name], show_files: true, header: false)
      lines = output.lines
      expect(lines.size).to eq(3)
      # First row carries the torrent name; continuation rows blank it.
      expect(lines[0]).to match(/test-dir/)
      expect(lines[1]).not_to match(/test-dir/)
      expect(lines[0]).to match(/subdir\/file1\.txt$/)
      expect(lines[2]).to match(/other\.txt$/)
    end
  end

  describe "box format" do
    it "draws UTF-8 borders" do
      formatter.charset = Torinfo::BoxCharset::Utf8
      output = render(formatter, [single], [Torinfo::Field::Name])
      expect(output).to contain("┌")
      expect(output).to match(/│ Name +│/)
      expect(output).to match(/│ test-file\.txt │/)
      expect(output).to contain("└")
    end

    it "draws ASCII borders" do
      formatter.charset = Torinfo::BoxCharset::Ascii
      output = render(formatter, [single], [Torinfo::Field::Name])
      expect(output).to match(/\A\+-+\+\n/)
      expect(output).to match(/\| Name +\|/)
    end

    it "includes a header separator when header is on and omits it otherwise" do
      formatter.charset = Torinfo::BoxCharset::Ascii
      with_header = render(formatter, [single], [Torinfo::Field::Name], header: true)
      # top border, header row, separator, data row, bottom border
      expect(with_header.lines.size).to eq(5)
      without = render(formatter, [single], [Torinfo::Field::Name], header: false)
      # top border, data row, bottom border
      expect(without.lines.size).to eq(3)
    end
  end
end
