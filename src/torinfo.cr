require "./torinfo/byte_string"
require "./torinfo/bencode"
require "./torinfo/torrent_file"
require "./torinfo/torrent"
require "./torinfo/formatters/text"
require "./torinfo/formatters/json"
require "./torinfo/formatters/bash_vars"
require "./torinfo/formatters/bash_func"
require "./torinfo/cli"

module Torinfo
  VERSION = {{ `shards version`.strip.stringify }}
end
