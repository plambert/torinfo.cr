require "./torinfo/byte_string"
require "./torinfo/bencode"
require "./torinfo/size_unit"
require "./torinfo/box_charset"
require "./torinfo/output_format"
require "./torinfo/torrent_file"
require "./torinfo/torrent"
require "./torinfo/field"
require "./torinfo/formatters/info"
require "./torinfo/formatters/table"
require "./torinfo/formatters/delimited"
require "./torinfo/formatters/json"
require "./torinfo/formatters/yaml"
require "./torinfo/formatters/bash_vars"
require "./torinfo/formatters/bash_func"
require "./torinfo/cli"

module Torinfo
  VERSION = {{ `shards version`.strip.stringify }}
end
