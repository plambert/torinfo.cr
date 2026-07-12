require "../spec_helper"
require "json"

Spectator.describe Torinfo::CLI do
  describe ".parse" do
    it "defaults to text output" do
      cli = Torinfo::CLI.parse(["spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --json" do
      cli = Torinfo::CLI.parse(["--json", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:json)
    end

    it "parses --text" do
      cli = Torinfo::CLI.parse(["--text", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --bashv with prefix" do
      cli = Torinfo::CLI.parse(["--bashv", "t_", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_vars)
      expect(cli.bashv_prefix).to eq("t_")
    end

    it "parses --bashf with function name" do
      cli = Torinfo::CLI.parse(["--bashf", "myfunc", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_func)
      expect(cli.bashf_func).to eq("myfunc")
    end

    it "collects field flags" do
      cli = Torinfo::CLI.parse(["--name", "--hash", "spec/fixtures/v1_single.torrent"])
      expect(cli.selected_fields).to contain_exactly(:name, :hash)
    end

    it "selects the total size field with --size" do
      cli = Torinfo::CLI.parse(["--size", "spec/fixtures/v1_single.torrent"])
      expect(cli.selected_fields).to contain_exactly(:total_size)
    end

    it "rejects the old --total-size spelling" do
      expect do
        Torinfo::CLI.parse(["--total-size", "spec/fixtures/v1_single.torrent"])
      end.to raise_error(Shell::AutoComplete::ParseError, /unknown flag/)
    end

    it "defaults the size unit to human" do
      cli = Torinfo::CLI.parse(["spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Human)
    end

    it "parses --human" do
      cli = Torinfo::CLI.parse(["--human", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Human)
    end

    it "parses --bytes" do
      cli = Torinfo::CLI.parse(["--bytes", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Bytes)
    end

    it "parses --kilobytes" do
      cli = Torinfo::CLI.parse(["--kilobytes", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Kilobytes)
    end

    it "parses --megabytes" do
      cli = Torinfo::CLI.parse(["--megabytes", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Megabytes)
    end

    it "parses --gigabytes" do
      cli = Torinfo::CLI.parse(["--gigabytes", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Gigabytes)
    end

    it "parses --size-unit with a named unit" do
      cli = Torinfo::CLI.parse(["--size-unit", "megabytes", "spec/fixtures/v1_single.torrent"])
      expect(cli.size_unit).to eq(Torinfo::SizeUnit::Megabytes)
    end

    it "parses --strftime format" do
      cli = Torinfo::CLI.parse(["--strftime", "%Y-%m-%d", "spec/fixtures/v1_single.torrent"])
      expect(cli.strftime).to eq("%Y-%m-%d")
    end

    it "parses --unix-epoch" do
      cli = Torinfo::CLI.parse(["--unix-epoch", "spec/fixtures/v1_single.torrent"])
      expect(cli.unix_epoch).to be_true
    end

    it "parses --raw" do
      cli = Torinfo::CLI.parse(["--raw", "spec/fixtures/v1_single.torrent"])
      expect(cli.raw).to be_true
    end

    it "raises ParseError for unknown option" do
      expect do
        Torinfo::CLI.parse(["--nope", "spec/fixtures/v1_single.torrent"])
      end.to raise_error(Shell::AutoComplete::ParseError, /unknown flag/)
    end

    it "raises ParseError for --bashv without prefix argument" do
      expect do
        Torinfo::CLI.parse(["--bashv"])
      end.to raise_error(Shell::AutoComplete::ParseError, /requires a value/)
    end

    it "raises ParseError when no torrent files are given" do
      expect do
        Torinfo::CLI.parse([] of String)
      end.to raise_error(Shell::AutoComplete::ParseError, /positional/)
    end

    it "collects torrent file paths" do
      cli = Torinfo::CLI.parse(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(cli.torrent_paths.map(&.to_s)).to eq(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
    end
  end

  describe "#emit" do
    it "outputs text for a torrent file" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["spec/fixtures/v1_single.torrent"]).emit(io)
      expect(io.to_s).to match(/Name: test-file\.txt/)
    end

    it "outputs raw value without label when --raw" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--raw", "--name", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect(io.to_s.chomp).to eq("test-file.txt")
    end

    it "outputs JSON when --json" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--json", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect { JSON.parse(io.to_s) }.not_to raise_error
    end

    it "humanizes the total size by default" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--raw", "--size", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect(io.to_s.chomp).to eq(1024_i64.humanize)
    end

    it "shows exact bytes with --bytes" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--bytes", "--raw", "--size", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect(io.to_s.chomp).to eq("1024")
    end

    it "shows scaled sizes with --kilobytes" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--kilobytes", "--raw", "--size", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect(io.to_s.chomp).to eq("1.0")
    end

    it "leaves JSON sizes as integer bytes regardless of unit" do
      io = IO::Memory.new
      Torinfo::CLI.parse(["--json", "--megabytes", "spec/fixtures/v1_single.torrent"]).emit(io)
      expect(JSON.parse(io.to_s)["total_size"]).to eq(1024)
    end

    it "raises ParseError for --bashv with field specifiers" do
      io = IO::Memory.new
      expect do
        Torinfo::CLI.parse(["--bashv", "t_", "--name", "spec/fixtures/v1_single.torrent"]).emit(io)
      end.to raise_error(Shell::AutoComplete::ParseError, /cannot combine/)
    end

    it "raises ParseError for --bashf with field specifiers" do
      io = IO::Memory.new
      expect do
        Torinfo::CLI.parse(["--bashf", "f", "--hash", "spec/fixtures/v1_single.torrent"]).emit(io)
      end.to raise_error(Shell::AutoComplete::ParseError, /cannot combine/)
    end

    it "raises ParseError for --raw with --json" do
      io = IO::Memory.new
      expect do
        Torinfo::CLI.parse(["--raw", "--json", "spec/fixtures/v1_single.torrent"]).emit(io)
      end.to raise_error(Shell::AutoComplete::ParseError, /only valid with --text/)
    end

    it "raises ParseError for --raw with --bashv" do
      io = IO::Memory.new
      expect do
        Torinfo::CLI.parse(["--raw", "--bashv", "t_", "spec/fixtures/v1_single.torrent"]).emit(io)
      end.to raise_error(Shell::AutoComplete::ParseError, /only valid with --text/)
    end
  end
end
