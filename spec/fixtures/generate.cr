require "digest/sha1"
require "digest/sha256"
require "../support/fixture_builder"

dir = File.dirname(__FILE__)

{
  "v1_single" => {FixtureBuilder.v1_single_info_bytes, false},
  "v1_multi"  => {FixtureBuilder.v1_multi_info_bytes, true},
  "v2_single" => {FixtureBuilder.v2_single_info_bytes, false},
  "hybrid"    => {FixtureBuilder.hybrid_info_bytes, false},
}.each do |name, (info_bytes, announce_list)|
  path = File.join(dir, "#{name}.torrent")
  FixtureBuilder.write_torrent(path, info_bytes, announce_list)
  sha1 = Digest::SHA1.digest(info_bytes).map { |b| "%02x" % b }.join
  sha256 = Digest::SHA256.digest(info_bytes).map { |b| "%02x" % b }.join
  puts "#{name}.torrent: sha1=#{sha1} sha256=#{sha256}"
end

puts "Done. 4 fixtures written to #{dir}"
