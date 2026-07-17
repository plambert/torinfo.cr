require "../../spec_helper"

Spectator.describe Torinfo::Formatters::BashFunc do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  subject(formatter) { Torinfo::Formatters::BashFunc.new }
  let(all_fields) { Torinfo::OutputFormat::BashFunc.default_fields }

  def render(formatter, torrent, fields, show_files = false, func = "myfunc", tty = false) : String
    io = IO::Memory.new
    formatter.format_one(torrent, io, func, tty, fields, show_files)
    io.to_s
  end

  describe "#format_one (non-TTY)" do
    it "starts with the function name" do
      expect(render(formatter, single, all_fields)).to start_with("myfunc ")
    end

    it "passes selected scalar fields in order, size as bytes and format numeric" do
      output = render(formatter, single, [Torinfo::Field::Name, Torinfo::Field::Format, Torinfo::Field::Size])
      expect(output.chomp).to eq("myfunc 'test-file.txt' 1 1024 -- --")
    end

    it "always emits both -- separators" do
      output = render(formatter, single, [Torinfo::Field::Name])
      expect(output.chomp).to eq("myfunc 'test-file.txt' -- --")
    end

    it "places trackers between the separators only when selected" do
      selected = render(formatter, single, [Torinfo::Field::Name, Torinfo::Field::Trackers])
      expect(selected.chomp).to eq("myfunc 'test-file.txt' -- 'https://tracker.example.com/announce' --")
      without = render(formatter, single, [Torinfo::Field::Name])
      expect(without.chomp).to eq("myfunc 'test-file.txt' -- --")
    end

    it "appends files after the second separator as path size groups" do
      output = render(formatter, multi, [Torinfo::Field::Name], show_files: true)
      expect(output.chomp).to eq(
        "myfunc 'test-dir' -- -- 'subdir/file1.txt' 1000 'subdir/file2.txt' 2000 'other.txt' 500"
      )
    end

    it "adds the formatted size after the byte count when a unit is selected" do
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      formatter.size_companion = true
      output = render(formatter, multi, [Torinfo::Field::Size], show_files: true)
      expect(output.chomp).to eq(
        "myfunc 3500 '3.4' -- -- 'subdir/file1.txt' 1000 '1.0' 'subdir/file2.txt' 2000 '2.0' 'other.txt' 500 '0.5'"
      )
    end
  end

  describe "#format_one (TTY)" do
    it "puts the function name and first arg on the first line" do
      output = render(formatter, single, all_fields, tty: true)
      expect(output.lines.first).to match(/\Amyfunc '.*' \\$/)
    end

    it "leaves no trailing backslash on the last line" do
      output = render(formatter, single, all_fields, tty: true)
      expect(output.lines.last.strip).not_to end_with('\\')
    end
  end

  describe "#format_all" do
    it "calls the function once per torrent" do
      io = IO::Memory.new
      formatter.format_all([single, multi], io, "myfunc", false, [Torinfo::Field::Name], false)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect(line).to start_with("myfunc ") }
    end
  end
end
