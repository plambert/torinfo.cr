require "../spec_helper"
require "json"

Spectator.describe Torinfo::CLI do
  def parse(args) : Torinfo::CLI
    Torinfo::CLI.parse(args)
  end

  def emit(args) : String
    io = IO::Memory.new
    Torinfo::CLI.parse(args).emit(io)
    io.to_s
  end

  describe "output format resolution" do
    it "defaults to info for a single torrent" do
      cli = parse(["spec/fixtures/v1_single.torrent"])
      expect(cli.output_format).to eq(Torinfo::OutputFormat::Info)
    end

    it "defaults to table for several torrents" do
      cli = parse(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(cli.output_format).to eq(Torinfo::OutputFormat::Table)
    end

    it "honors an explicit format flag" do
      expect(parse(["--json", "spec/fixtures/v1_single.torrent"]).output_format).to eq(Torinfo::OutputFormat::Json)
      expect(parse(["--box", "spec/fixtures/v1_single.torrent"]).output_format).to eq(Torinfo::OutputFormat::Box)
      expect(parse(["--bashv", "t_", "spec/fixtures/v1_single.torrent"]).output_format).to eq(Torinfo::OutputFormat::BashVars)
    end

    it "rejects more than one format" do
      expect { parse(["--json", "--yaml", "spec/fixtures/v1_single.torrent"]).output_format }
        .to raise_error(Shell::AutoComplete::ParseError, /only one output format/)
    end
  end

  describe "--fields" do
    it "is cumulative and comma-split, order preserved" do
      cli = parse(["--fields", "size,name", "--fields", "visibility", "spec/fixtures/v1_single.torrent"])
      expect(cli.resolve_fields(Torinfo::OutputFormat::Info)).to eq(
        [Torinfo::Field::Size, Torinfo::Field::Name, Torinfo::Field::Visibility]
      )
    end

    it "dedups while keeping first position" do
      cli = parse(["--fields", "name,size,name", "spec/fixtures/v1_single.torrent"])
      expect(cli.resolve_fields(Torinfo::OutputFormat::Info)).to eq([Torinfo::Field::Name, Torinfo::Field::Size])
    end

    it "falls back to the format default when empty" do
      cli = parse(["spec/fixtures/v1_single.torrent"])
      expect(cli.resolve_fields(Torinfo::OutputFormat::Table)).to eq(Torinfo::OutputFormat::Table.default_fields)
    end

    it "rejects an unknown field at parse time" do
      expect { parse(["--fields", "nope", "spec/fixtures/v1_single.torrent"]) }
        .to raise_error(Shell::AutoComplete::ParseError, /unknown field/)
    end

    it "rejects files as a field" do
      expect { parse(["--fields", "files", "spec/fixtures/v1_single.torrent"]) }
        .to raise_error(Shell::AutoComplete::ParseError, /--files/)
    end
  end

  describe "size units" do
    it "defaults to human" do
      expect(parse(["spec/fixtures/v1_single.torrent"]).size_unit).to eq(Torinfo::SizeUnit::Human)
    end

    it "parses the shortcut flags" do
      expect(parse(["--gigabytes", "spec/fixtures/v1_single.torrent"]).size_unit).to eq(Torinfo::SizeUnit::Gigabytes)
      expect(parse(["--bytes", "spec/fixtures/v1_single.torrent"]).size_unit).to eq(Torinfo::SizeUnit::Bytes)
    end
  end

  describe "validations" do
    it "rejects --header on a non-tabular format" do
      expect { emit(["--info", "--header", "spec/fixtures/v1_single.torrent"]) }
        .to raise_error(Shell::AutoComplete::ParseError, /--header.*not valid/)
    end

    it "allows --header on box" do
      expect { emit(["--box", "--header", "spec/fixtures/v1_single.torrent"]) }.not_to raise_error
    end

    it "rejects --utf8 without --box" do
      expect { emit(["--table", "--utf8", "spec/fixtures/v1_single.torrent"]) }
        .to raise_error(Shell::AutoComplete::ParseError, /only valid with --box/)
    end
  end

  describe "#emit output" do
    it "renders info by default for one torrent" do
      expect(emit(["spec/fixtures/v1_single.torrent"])).to match(/Name: test-file\.txt/)
    end

    it "renders a table for several torrents" do
      output = emit(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(output.lines.first).to match(/Size\s+Visibility\s+Created On\s+Name/)
    end

    it "emits valid JSON with kebab keys" do
      obj = JSON.parse(emit(["--json", "spec/fixtures/v1_single.torrent"]))
      expect(obj["created-on"].as_s).to eq("2024-01-01T00:00:00Z")
    end

    it "adds a size companion in structured output only when a unit is given" do
      plain = JSON.parse(emit(["--json", "--fields", "size", "spec/fixtures/v1_single.torrent"]))
      expect(plain.as_h.has_key?("size-gb")).to be_false
      with_unit = JSON.parse(emit(["--json", "--gigabytes", "--fields", "size", "spec/fixtures/v1_single.torrent"]))
      expect(with_unit["size-gb"].as_s).to eq("0.0")
    end

    it "keeps --files independent of the field set" do
      # default fields + files
      default_plus = emit(["--info", "--files", "spec/fixtures/v1_multi.torrent"])
      expect(default_plus).to match(/Name:/)
      expect(default_plus).to match(/Files:/)
      # only size + files
      only_size = emit(["--info", "--fields", "size", "--files", "spec/fixtures/v1_multi.torrent"])
      expect(only_size).to match(/Size:/)
      expect(only_size).to match(/Files:/)
      expect(only_size).not_to match(/Name:/)
    end

    it "draws an ASCII box when forced" do
      output = emit(["--box", "--ascii", "--fields", "name", "spec/fixtures/v1_single.torrent"])
      expect(output).to match(/\A\+-+\+\n/)
    end
  end

  describe ".parse positionals" do
    it "requires at least one torrent" do
      expect { parse([] of String) }.to raise_error(Shell::AutoComplete::ParseError, /positional/)
    end

    it "collects torrent paths" do
      cli = parse(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
      expect(cli.torrent_paths.map(&.to_s)).to eq(["spec/fixtures/v1_single.torrent", "spec/fixtures/v1_multi.torrent"])
    end
  end
end
