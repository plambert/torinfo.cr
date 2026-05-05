require "../spec_helper"
require "json"

Spectator.describe Torinfo::CLI do
  describe "#initialize" do
    it "defaults to text output" do
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --json" do
      cli = Torinfo::CLI.new(["--json", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:json)
    end

    it "parses --text" do
      cli = Torinfo::CLI.new(["--text", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:text)
    end

    it "parses --bashv with prefix" do
      cli = Torinfo::CLI.new(["--bashv", "t_", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_vars)
      expect(cli.bash_prefix).to eq("t_")
    end

    it "parses --bashf with function name" do
      cli = Torinfo::CLI.new(["--bashf", "myfunc", "spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(:bash_func)
      expect(cli.bash_func_name).to eq("myfunc")
    end

    it "collects field flags" do
      cli = Torinfo::CLI.new(["--name", "--hash", "spec/fixtures/v1_single.torrent"])
      expect(cli.fields).to contain_exactly(:name, :hash)
    end

    it "parses --strftime format" do
      cli = Torinfo::CLI.new(["--strftime", "%Y-%m-%d", "spec/fixtures/v1_single.torrent"])
      expect(cli.time_format).to eq("%Y-%m-%d")
    end

    it "parses --unix-epoch" do
      cli = Torinfo::CLI.new(["--unix-epoch", "spec/fixtures/v1_single.torrent"])
      expect(cli.unix_epoch?).to be_true
    end

    it "raises ArgumentError for --bashv with field specifiers" do
      expect {
        Torinfo::CLI.new(["--bashv", "t_", "--name", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /cannot combine/)
    end

    it "raises ArgumentError for --bashf with field specifiers" do
      expect {
        Torinfo::CLI.new(["--bashf", "f", "--hash", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /cannot combine/)
    end

    it "parses --raw" do
      cli = Torinfo::CLI.new(["--raw", "spec/fixtures/v1_single.torrent"])
      expect(cli.raw?).to be_true
    end

    it "raises ArgumentError for --raw with --json" do
      expect {
        Torinfo::CLI.new(["--raw", "--json", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /only valid with --text/)
    end

    it "raises ArgumentError for --raw with --bashv" do
      expect {
        Torinfo::CLI.new(["--raw", "--bashv", "t_", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /only valid with --text/)
    end

    it "raises ArgumentError for unknown option" do
      expect {
        Torinfo::CLI.new(["--nope", "spec/fixtures/v1_single.torrent"])
      }.to raise_error(ArgumentError, /unknown option/)
    end

    it "raises ArgumentError for --bashv without prefix argument" do
      expect {
        Torinfo::CLI.new(["--bashv"])
      }.to raise_error(ArgumentError, /requires/)
    end

    it "collects torrent file paths" do
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(cli.torrent_paths).to eq(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
    end
  end

  describe "#run" do
    it "outputs text for a torrent file" do
      io = IO::Memory.new
      cli = Torinfo::CLI.new(["spec/fixtures/v1_single.torrent"])
      cli.run(io)
      expect(io.to_s).to match(/Name: test-file\.txt/)
    end

    it "outputs raw value without label when --raw" do
      io = IO::Memory.new
      cli = Torinfo::CLI.new(["--raw", "--name", "spec/fixtures/v1_single.torrent"])
      cli.run(io)
      expect(io.to_s.chomp).to eq("test-file.txt")
    end

    it "outputs JSON when --json" do
      io = IO::Memory.new
      cli = Torinfo::CLI.new(["--json", "spec/fixtures/v1_single.torrent"])
      cli.run(io)
      expect { JSON.parse(io.to_s) }.not_to raise_error
    end
  end
end
