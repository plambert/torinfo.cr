require "../../spec_helper"
require "json"

Spectator.describe Torinfo::Formatters::Json do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  let(formatter) { Torinfo::Formatters::Json.new }
  let(all_fields) { Torinfo::OutputFormat::Json.default_fields }

  def parse(formatter, torrent, fields, show_files = false) : JSON::Any
    io = IO::Memory.new
    formatter.format_one(torrent, io, fields, show_files)
    JSON.parse(io.to_s)
  end

  describe "#format_one" do
    it "emits kebab keys and a numeric format" do
      obj = parse(formatter, single, all_fields)
      expect(obj["name"].as_s).to eq("test-file.txt")
      expect(obj["format"].as_i).to eq(1)
      expect(obj["created-on"].as_s).to eq("2024-01-01T00:00:00Z")
      expect(obj["hash"].as_s).to start_with("v1 ")
    end

    it "emits size as bytes with no companion by default" do
      obj = parse(formatter, single, [Torinfo::Field::Size])
      expect(obj["size"].as_i64).to eq(1024_i64)
      expect(obj.as_h.has_key?("size-human")).to be_false
    end

    it "adds a size-<unit> companion when a unit is selected" do
      formatter.size_unit = Torinfo::SizeUnit::Gigabytes
      formatter.size_companion = true
      obj = parse(formatter, single, [Torinfo::Field::Size])
      expect(obj["size"].as_i64).to eq(1024_i64)
      expect(obj["size-gb"].as_s).to eq("0.0")
    end

    it "restricts keys to the selected fields" do
      obj = parse(formatter, single, [Torinfo::Field::Name])
      expect(obj.as_h.keys).to eq(["name"])
    end

    it "omits files unless requested" do
      expect(parse(formatter, single, all_fields).as_h.has_key?("files")).to be_false
      obj = parse(formatter, single, all_fields, show_files: true)
      expect(obj["files"].as_a.size).to eq(1)
      expect(obj["files"][0]["path"].as_s).to eq("test-file.txt")
      expect(obj["files"][0]["size"].as_i64).to eq(1024_i64)
    end

    it "mirrors the unit companion onto file sizes" do
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      formatter.size_companion = true
      obj = parse(formatter, multi, [Torinfo::Field::Name], show_files: true)
      first = obj["files"][0]
      expect(first["size"].as_i64).to eq(1000_i64)
      expect(first["size-kb"].as_s).to eq("1.0")
    end

    it "uses null for absent optional fields" do
      # v1_single has no v2 pieces-root; the file object's pieces-root is null.
      obj = parse(formatter, single, [] of Torinfo::Field, show_files: true)
      expect(obj["files"][0]["pieces-root"].raw).to be_nil
    end
  end

  describe "#format_all" do
    it "emits one object per line (NDJSON)" do
      io = IO::Memory.new
      formatter.format_all([single, multi], io, all_fields, false)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
    end
  end
end

Spectator.describe Torinfo::Formatters::Yaml do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  let(formatter) { Torinfo::Formatters::Yaml.new }

  def render(formatter, torrent, fields, show_files = false) : String
    io = IO::Memory.new
    formatter.format_one(torrent, io, fields, show_files)
    io.to_s
  end

  it "emits a parseable document with kebab keys" do
    output = render(formatter, single, Torinfo::OutputFormat::Yaml.default_fields)
    parsed = YAML.parse(output)
    expect(parsed["name"].as_s).to eq("test-file.txt")
    expect(parsed["format"].as_i).to eq(1)
    expect(parsed["created-on"].as_s).to eq("2024-01-01T00:00:00Z")
  end

  it "emits size as bytes plus a companion when a unit is selected" do
    formatter.size_unit = Torinfo::SizeUnit::Gigabytes
    formatter.size_companion = true
    parsed = YAML.parse(render(formatter, single, [Torinfo::Field::Size]))
    expect(parsed["size"].as_i).to eq(1024)
    expect(parsed["size-gb"].as_s).to eq("0.0")
  end

  it "emits trackers as a sequence" do
    parsed = YAML.parse(render(formatter, multi, [Torinfo::Field::Trackers]))
    expect(parsed["trackers"].as_a.map(&.as_s)).to contain("https://tracker.example.com/announce")
  end

  it "emits one document per torrent" do
    io = IO::Memory.new
    formatter.format_all([single, multi], io, [Torinfo::Field::Name], false)
    expect(io.to_s.scan(/^---/m).size).to eq(2)
  end
end
