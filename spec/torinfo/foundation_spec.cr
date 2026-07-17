require "../spec_helper"

Spectator.describe Torinfo::SizeUnit do
  describe "#suffix" do
    it "maps units to companion suffixes" do
      expect(Torinfo::SizeUnit::Human.suffix).to eq("human")
      expect(Torinfo::SizeUnit::Kilobytes.suffix).to eq("kb")
      expect(Torinfo::SizeUnit::Megabytes.suffix).to eq("mb")
      expect(Torinfo::SizeUnit::Gigabytes.suffix).to eq("gb")
      expect(Torinfo::SizeUnit::Bytes.suffix).to be_nil
    end
  end

  describe "#bytes?" do
    it "is true only for Bytes" do
      expect(Torinfo::SizeUnit::Bytes.bytes?).to be_true
      expect(Torinfo::SizeUnit::Human.bytes?).to be_false
    end
  end
end

Spectator.describe Torinfo::Field do
  describe "#token / #bash_name / #label" do
    it "renders kebab, snake and Title forms" do
      expect(Torinfo::Field::CreatedOn.token).to eq("created-on")
      expect(Torinfo::Field::CreatedOn.bash_name).to eq("created_on")
      expect(Torinfo::Field::CreatedOn.label).to eq("Created On")
      expect(Torinfo::Field::Size.token).to eq("size")
      expect(Torinfo::Field::PieceCount.label).to eq("Piece Count")
    end
  end

  describe ".parse_token" do
    it "parses a valid token" do
      expect(Torinfo::Field.parse_token("piece-size")).to eq(Torinfo::Field::PieceSize)
    end

    it "rejects an unknown token" do
      expect { Torinfo::Field.parse_token("nope") }.to raise_error(ArgumentError, /unknown field/)
    end

    it "rejects the reserved files token" do
      expect { Torinfo::Field.parse_token("files") }.to raise_error(ArgumentError, /--files/)
    end
  end

  describe "#render" do
    let(torrent) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
    let(visual) { Torinfo::RenderContext.new(visual: true) }
    let(flat) { Torinfo::RenderContext.new(visual: false) }

    it "renders format as a label in visual context and numeric otherwise" do
      expect(Torinfo::Field::Format.render(torrent, visual)).to eq("v1")
      expect(Torinfo::Field::Format.render(torrent, flat)).to eq("1")
    end

    it "renders size scaled in visual context and as bytes otherwise" do
      gib = Torinfo::RenderContext.new(unit: Torinfo::SizeUnit::Bytes, visual: true)
      expect(Torinfo::Field::Size.render(torrent, gib)).to eq("1024")
      expect(Torinfo::Field::Size.render(torrent, flat)).to eq("1024")
      human = Torinfo::RenderContext.new(unit: Torinfo::SizeUnit::Human, visual: true)
      expect(Torinfo::Field::Size.render(torrent, human)).to eq(1024_i64.humanize)
    end

    it "joins trackers with a semicolon" do
      expect(Torinfo::Field::Trackers.render(torrent, flat)).to eq("https://tracker.example.com/announce")
    end

    it "ignores strftime in flat context" do
      ctx = Torinfo::RenderContext.new(strftime: "%Y", visual: false)
      expect(Torinfo::Field::CreatedOn.render(torrent, ctx)).to eq("2024-01-01T00:00:00Z")
    end

    it "honors strftime in visual context" do
      ctx = Torinfo::RenderContext.new(strftime: "%Y", visual: true)
      expect(Torinfo::Field::CreatedOn.render(torrent, ctx)).to eq("2024")
    end
  end
end

Spectator.describe Torinfo::OutputFormat do
  it "classifies formats" do
    expect(Torinfo::OutputFormat::Info.visual?).to be_true
    expect(Torinfo::OutputFormat::Table.visual?).to be_true
    expect(Torinfo::OutputFormat::Tsv.visual?).to be_false
    expect(Torinfo::OutputFormat::Box.tabular?).to be_true
    expect(Torinfo::OutputFormat::Json.structured?).to be_true
    expect(Torinfo::OutputFormat::Csv.header_capable?).to be_true
    expect(Torinfo::OutputFormat::Info.header_capable?).to be_false
  end

  describe "#default_fields" do
    it "is the compact summary for tabular formats" do
      expect(Torinfo::OutputFormat::Table.default_fields).to eq(
        [Torinfo::Field::Size, Torinfo::Field::Visibility, Torinfo::Field::CreatedOn, Torinfo::Field::Name]
      )
    end

    it "is every field for info and structured formats" do
      expect(Torinfo::OutputFormat::Info.default_fields).to eq(Torinfo::Field.values)
      expect(Torinfo::OutputFormat::Json.default_fields).to eq(Torinfo::Field.values)
    end
  end
end

Spectator.describe Torinfo::BoxCharset do
  describe "#resolve" do
    it "keeps a concrete choice" do
      expect(Torinfo::BoxCharset::Utf8.resolve("C")).to eq(Torinfo::BoxCharset::Utf8)
      expect(Torinfo::BoxCharset::Ascii.resolve("en_US.UTF-8")).to eq(Torinfo::BoxCharset::Ascii)
    end

    it "detects UTF-8 from the locale for Auto" do
      expect(Torinfo::BoxCharset::Auto.resolve("en_US.UTF-8")).to eq(Torinfo::BoxCharset::Utf8)
      expect(Torinfo::BoxCharset::Auto.resolve("en_US.utf8")).to eq(Torinfo::BoxCharset::Utf8)
    end

    it "falls back to ASCII for Auto without UTF-8" do
      expect(Torinfo::BoxCharset::Auto.resolve("C")).to eq(Torinfo::BoxCharset::Ascii)
      expect(Torinfo::BoxCharset::Auto.resolve(nil)).to eq(Torinfo::BoxCharset::Ascii)
    end
  end
end
