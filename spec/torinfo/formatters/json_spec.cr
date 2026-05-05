require "../../spec_helper"
require "json"

Spectator.describe Torinfo::Formatters::Json do
  let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  subject(formatter) { Torinfo::Formatters::Json.new }

  describe "#format_one" do
    let(output) do
      io = IO::Memory.new
      formatter.format_one(torrent, io)
      io.to_s
    end

    it "emits valid JSON" do
      expect { JSON.parse(output) }.not_to raise_error
    end

    it "includes name" do
      expect(JSON.parse(output)["name"].as_s).to eq("test-file.txt")
    end

    it "includes hash" do
      expect(JSON.parse(output)["hash"].as_s).to start_with("v1 ")
    end

    it "includes format_version" do
      expect(JSON.parse(output)["format_version"].as_i).to eq(1)
    end

    it "includes visibility" do
      expect(JSON.parse(output)["visibility"].as_s).to eq("public")
    end

    it "includes trackers as array" do
      trackers = JSON.parse(output)["trackers"].as_a
      expect(trackers.first.as_s).to eq("https://tracker.example.com/announce")
    end

    it "includes files as array of objects" do
      files = JSON.parse(output)["files"].as_a
      expect(files.size).to eq(1)
      expect(files[0]["path"].as_s).to eq("test-file.txt")
      expect(files[0]["size"].as_i64).to eq(1024_i64)
    end

    it "uses null for nil fields" do
      parsed = JSON.parse(output)
      expect(parsed["info_hash_v2"].raw).to be_nil
    end

    it "includes created_on in RFC 3339 by default" do
      expect(JSON.parse(output)["created_on"].as_s).to eq("2024-01-01T00:00:00Z")
    end
  end

  describe "#format_all (NDJSON)" do
    it "emits one JSON object per line" do
      torrent2 = Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent")
      io = IO::Memory.new
      formatter.format_all([torrent, torrent2], io)
      lines = io.to_s.strip.split('\n')
      expect(lines.size).to eq(2)
      lines.each { |line| expect { JSON.parse(line) }.not_to raise_error }
    end
  end
end
