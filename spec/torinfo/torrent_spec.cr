require "../spec_helper"
require "../support/fixture_builder"
require "digest/sha1"
require "digest/sha256"

Spectator.describe Torinfo::Torrent do
  describe ".from_file (v1 single-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }

    it "reads the name" do
      expect(torrent.name).to eq("test-file.txt")
    end

    it "sets format_version to 1" do
      expect(torrent.format_version).to eq(1)
    end

    it "computes the v1 info hash" do
      expected = Digest::SHA1.digest(FixtureBuilder.v1_single_info_bytes)
      expect(torrent.info_hash_v1.not_nil!.bytes).to eq(expected)
    end

    it "returns nil for v2 info hash" do
      expect(torrent.info_hash_v2).to be_nil
    end

    it "returns hash prefixed with 'v1 '" do
      expect(torrent.hash).to start_with("v1 ")
      expect(torrent.hash.size).to eq(43) # "v1 " + 40 hex chars
    end

    it "reads piece_size" do
      expect(torrent.piece_size).to eq(262144_i64)
    end

    it "reads piece_count" do
      expect(torrent.piece_count).to eq(1_i64)
    end

    it "reads total_size" do
      expect(torrent.total_size).to eq(1024_i64)
    end

    it "reads created_by" do
      expect(torrent.created_by).to eq("torinfo-test")
    end

    it "reads created_on as UTC Time" do
      time = torrent.created_on
      expect(time).not_to be_nil
      expect(time.not_nil!.to_unix).to eq(1704067200_i64)
    end

    it "reads comment" do
      expect(torrent.comment).to eq("test torrent")
    end

    it "reads source" do
      expect(torrent.source).to eq("TEST")
    end

    it "is not private" do
      expect(torrent.private?).to be_false
    end

    it "returns 'public' visibility" do
      expect(torrent.visibility).to eq("public")
    end

    it "reads trackers" do
      expect(torrent.trackers).to eq(["https://tracker.example.com/announce"])
    end

    it "has one file entry" do
      expect(torrent.files.size).to eq(1)
    end

    it "file has correct path (torrent name)" do
      expect(torrent.files[0].path).to eq("test-file.txt")
    end

    it "file has correct size" do
      expect(torrent.files[0].size).to eq(1024_i64)
    end

    it "file has no pieces_root (v1 only)" do
      expect(torrent.files[0].pieces_root).to be_nil
    end
  end

  describe ".from_file (v1 multi-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }

    it "reads the name" do
      expect(torrent.name).to eq("test-dir")
    end

    it "sets format_version to 1" do
      expect(torrent.format_version).to eq(1)
    end

    it "is private" do
      expect(torrent.private?).to be_true
    end

    it "returns 'private' visibility" do
      expect(torrent.visibility).to eq("private")
    end

    it "reads total_size as sum of files" do
      expect(torrent.total_size).to eq(3500_i64)
    end

    it "has three file entries" do
      expect(torrent.files.size).to eq(3)
    end

    it "file paths are joined" do
      paths = torrent.files.map(&.path)
      expect(paths).to contain_exactly("subdir/file1.txt", "subdir/file2.txt", "other.txt")
    end

    it "file sizes are correct" do
      sizes = torrent.files.map(&.size)
      expect(sizes).to contain_exactly(1000_i64, 2000_i64, 500_i64)
    end

    it "dedupes trackers from announce and announce-list" do
      expect(torrent.trackers).to contain("https://tracker.example.com/announce")
      expect(torrent.trackers).to contain("https://backup.example.com/announce")
      expect(torrent.trackers.uniq.size).to eq(torrent.trackers.size)
    end
  end

  describe ".from_file (v2 single-file)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v2_single.torrent") }

    it "sets format_version to 2" do
      expect(torrent.format_version).to eq(2)
    end

    it "returns nil for v1 info hash" do
      expect(torrent.info_hash_v1).to be_nil
    end

    it "computes the v2 info hash" do
      expected = Digest::SHA256.digest(FixtureBuilder.v2_single_info_bytes)
      expect(torrent.info_hash_v2.not_nil!.bytes).to eq(expected)
    end

    it "returns hash prefixed with 'v2 '" do
      expect(torrent.hash).to start_with("v2 ")
      expect(torrent.hash.size).to eq(67) # "v2 " + 64 hex chars
    end

    it "reads name" do
      expect(torrent.name).to eq("test-file-v2.txt")
    end

    it "has one file entry from file tree" do
      expect(torrent.files.size).to eq(1)
    end

    it "file has correct path from file tree key" do
      expect(torrent.files[0].path).to eq("test-file-v2.txt")
    end

    it "file has correct size" do
      expect(torrent.files[0].size).to eq(1024_i64)
    end

    it "file has a pieces_root" do
      pr = torrent.files[0].pieces_root
      expect(pr).not_to be_nil
      expect(pr.not_nil!.bytes.size).to eq(32)
    end
  end

  describe ".from_file (hybrid)" do
    subject(torrent) { Torinfo::Torrent.from_file("spec/fixtures/hybrid.torrent") }

    it "sets format_version to 3" do
      expect(torrent.format_version).to eq(3)
    end

    it "has a v1 info hash" do
      expected = Digest::SHA1.digest(FixtureBuilder.hybrid_info_bytes)
      expect(torrent.info_hash_v1.not_nil!.bytes).to eq(expected)
    end

    it "has a v2 info hash" do
      expected = Digest::SHA256.digest(FixtureBuilder.hybrid_info_bytes)
      expect(torrent.info_hash_v2.not_nil!.bytes).to eq(expected)
    end

    it "prefers v1 in .hash" do
      expect(torrent.hash).to start_with("v1 ")
    end

    it "reads files from file tree" do
      expect(torrent.files.size).to eq(1)
      expect(torrent.files[0].path).to eq("hybrid-file.txt")
    end
  end
end
