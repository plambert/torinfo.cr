require "../../spec_helper"

Spectator.describe Torinfo::Formatters::BashVars do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::BashVars.new }

  describe "#format_one (non-TTY, single file)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: false)
      io.to_s
    end

    it "includes all scalar variables on one line" do
      expect(output).to match(/t_name='test-file\.txt'/)
      expect(output).to match(/t_hash='v1 [0-9a-f]{40}'/)
      expect(output).to match(/t_visibility=public/)
      expect(output).to match(/t_format_version=1/)
      expect(output).to match(/t_piece_count=1/)
    end

    it "includes path variable" do
      expect(output).to match(/t_path='spec\/fixtures\/v1_single\.torrent'/)
    end

    it "includes arrays" do
      expect(output).to match(/t_trackers=\('https:\/\/tracker\.example\.com\/announce'\)/)
      expect(output).to match(/t_filename=\('test-file\.txt'\)/)
      expect(output).to match(/t_filesize=\(1024\)/)
    end

    it "puts everything on one line" do
      expect(output.strip.count('\n')).to eq(0)
    end

    it "includes a variables array naming every emitted variable" do
      expect(output).to match(/t_variables=\(/)
      %w[t_path t_name t_hash t_created_by t_created_on t_comment t_source
        t_piece_count t_piece_size t_total_size t_visibility t_format_version
        t_trackers t_filename t_filesize].each do |var|
        expect(output).to match(/'#{var}'/)
      end
    end

    it "includes itself in the variables array" do
      expect(output).to match(/t_variables=\([^)]*'t_variables'[^)]*\)/)
    end
  end

  describe "#format_one (TTY, single file)" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: true)
      io.to_s
    end

    it "starts with path variable" do
      expect(output.lines.first).to match(/t_path=.*\\$/)
    end

    it "indents subsequent variables with two spaces" do
      output.lines[1..].each { |line| expect(line).to start_with("  t_") }
    end

    it "ends with no trailing backslash on last line" do
      expect(output.lines.last.strip).not_to end_with('\\')
    end
  end

  describe "#format_all (multiple files, no %d in prefix)" do
    let(torrent2) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "appends _1, _2 suffixes in non-TTY mode" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_", tty: false)
      output = io.to_s
      expect(output).to match(/t_1_name=/)
      expect(output).to match(/t_2_name=/)
    end

    it "separates entries with a blank line in TTY mode" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_", tty: true)
      expect(io.to_s).to match(/\n\n/)
    end

    it "emits a per-torrent variables manifest" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_", tty: false)
      output = io.to_s
      expect(output).to match(/t_1_variables=\([^)]*'t_1_variables'[^)]*\)/)
      expect(output).to match(/t_2_variables=\([^)]*'t_2_variables'[^)]*\)/)
    end
  end

  describe "#format_all (multiple files, %d in prefix)" do
    let(torrent2) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "uses sprintf formatting for prefix" do
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io, prefix: "t_%02d_", tty: false)
      output = io.to_s
      expect(output).to match(/t_01_name=/)
      expect(output).to match(/t_02_name=/)
    end
  end

  describe "quoting" do
    it "escapes single quotes in string values" do
      expect(formatter.bash_quote("it's here")).to eq("'it'\\''s here'")
    end

    it "does not quote integer-valued variables" do
      io = IO::Memory.new
      formatter.format_one(torrent, io, prefix: "t_", tty: false)
      expect(io.to_s).to match(/t_piece_count=1 /)
    end
  end
end
