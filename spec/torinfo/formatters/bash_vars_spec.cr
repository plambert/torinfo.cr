require "../../spec_helper"

Spectator.describe Torinfo::Formatters::BashVars do
  let(single) { Torinfo::Torrent.from_file("spec/fixtures/v1_single.torrent") }
  let(multi) { Torinfo::Torrent.from_file("spec/fixtures/v1_multi.torrent") }
  subject(formatter) { Torinfo::Formatters::BashVars.new }
  let(all_fields) { Torinfo::OutputFormat::BashVars.default_fields }

  def render(formatter, torrent, fields, show_files = false, prefix = "t_", tty = false) : String
    io = IO::Memory.new
    formatter.format_one(torrent, io, prefix, tty, fields, show_files)
    io.to_s
  end

  describe "#format_one (non-TTY)" do
    it "emits snake-case variable names" do
      output = render(formatter, single, all_fields)
      expect(output).to match(/t_name='test-file\.txt'/)
      expect(output).to match(/t_created_on='2024-01-01T00:00:00Z'/)
      expect(output).to match(/t_hash='v1 [0-9a-f]{40}'/)
    end

    it "emits size as bytes, format numeric, visibility unquoted" do
      output = render(formatter, single, all_fields)
      expect(output).to match(/t_size=1024(\s|$)/)
      expect(output).to match(/t_format=1(\s|$)/)
      expect(output).to match(/t_visibility=public(\s|$)/)
    end

    it "restricts variables to the selected fields" do
      output = render(formatter, single, [Torinfo::Field::Name])
      expect(output).to match(/t_name=/)
      expect(output).not_to match(/t_hash=/)
      expect(output).not_to match(/t_size=/)
    end

    it "emits trackers as an array" do
      output = render(formatter, single, [Torinfo::Field::Trackers])
      expect(output).to match(/t_trackers=\('https:\/\/tracker\.example\.com\/announce'\)/)
    end

    it "adds a size_<unit> scalar when a unit is selected" do
      formatter.size_unit = Torinfo::SizeUnit::Gigabytes
      formatter.size_companion = true
      output = render(formatter, single, [Torinfo::Field::Size])
      expect(output).to match(/t_size=1024 /)
      expect(output).to match(/t_size_gb='0\.0'/)
    end
  end

  describe "files" do
    it "adds filename and filesize arrays only with files" do
      expect(render(formatter, single, all_fields)).not_to match(/t_filename=/)
      output = render(formatter, multi, all_fields, show_files: true)
      expect(output).to match(/t_filename=\('subdir\/file1\.txt' 'subdir\/file2\.txt' 'other\.txt'\)/)
      expect(output).to match(/t_filesize=\(1000 2000 500\)/)
    end

    it "adds a filesize_<unit> array when a unit is selected" do
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      formatter.size_companion = true
      output = render(formatter, multi, [Torinfo::Field::Name], show_files: true)
      expect(output).to match(/t_filesize_kb=\('1\.0' '2\.0' '0\.5'\)/)
    end
  end

  describe "variables manifest" do
    it "lists every emitted variable including itself" do
      output = render(formatter, single, [Torinfo::Field::Name, Torinfo::Field::Size])
      expect(output).to match(/t_variables=\('t_name' 't_size' 't_variables'\)/)
    end

    it "includes companion and file variables in the manifest" do
      formatter.size_unit = Torinfo::SizeUnit::Kilobytes
      formatter.size_companion = true
      output = render(formatter, single, [Torinfo::Field::Size], show_files: true)
      expect(output).to match(/'t_size' 't_size_kb' 't_filename' 't_filesize' 't_filesize_kb' 't_variables'/)
    end
  end

  describe "#format_all prefix expansion" do
    it "appends _1/_2 for multiple torrents without a %d prefix" do
      io = IO::Memory.new
      formatter.format_all([single, multi], io, "t_", false, [Torinfo::Field::Name], false)
      expect(io.to_s).to match(/t_1_name=/)
      expect(io.to_s).to match(/t_2_name=/)
    end

    it "uses sprintf when the prefix has a %d" do
      io = IO::Memory.new
      formatter.format_all([single, multi], io, "t_%02d_", false, [Torinfo::Field::Name], false)
      expect(io.to_s).to match(/t_01_name=/)
      expect(io.to_s).to match(/t_02_name=/)
    end
  end

  describe "quoting" do
    it "escapes single quotes in string values" do
      expect(formatter.bash_quote("it's here")).to eq("'it'\\''s here'")
    end
  end
end
