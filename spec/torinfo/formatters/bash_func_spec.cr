require "../../spec_helper"

Spectator.describe Torinfo::Formatters::BashFunc do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::BashFunc.new }

  describe "#format_one (non-TTY)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, func_name: "myfunc", tty: false)
      io.to_s
    end

    it "starts with the function name" do
      expect(output).to start_with("myfunc ")
    end

    it "is a single line" do
      expect(output.strip.count('\n')).to eq(0)
    end

    it "contains the path as first argument" do
      expect(output).to match(/myfunc 'spec\/fixtures\/v1_single\.torrent' /)
    end

    it "contains -- separator before files" do
      expect(output).to match(/ -- /)
    end

    it "contains file path and size after --" do
      expect(output).to match(/-- 'test-file\.txt' 1024$/)
    end

    it "contains piece_count as bare integer" do
      # piece_count=1, between other args; check it appears unquoted
      expect(output).to match(/ 1 262144 /)
    end
  end

  describe "#format_one (TTY)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, func_name: "myfunc", tty: true)
      io.to_s
    end

    it "starts with function name and first argument on same line" do
      expect(output.lines.first).to match(/\Amyfunc '.*' \\$/)
    end

    it "indents continuation lines to align under first arg" do
      indent = "myfunc ".size
      output.lines[1...-1].each { |line| expect(line).to start_with(" " * indent) }
    end

    it "last line has no trailing backslash" do
      expect(output.lines.last.strip).not_to end_with('\\')
    end

    it "has -- on its own continuation line" do
      lines = output.lines
      expect(lines.any? { |line| line.strip == "-- \\" || line.strip == "--" }).to be_true
    end
  end

  describe "#format_all" do
    it "calls function once per torrent (non-TTY)" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, func_name: "myfunc", tty: false)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect(line).to start_with("myfunc ") }
    end

    it "separates torrent calls with blank line in TTY mode" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, func_name: "myfunc", tty: true)
      expect(io.to_s).to match(/\n\n/)
    end
  end
end
