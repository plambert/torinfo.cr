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
