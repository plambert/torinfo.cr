require "./torinfo"
require "./torinfo/cli"

Torinfo::CLI.dispatch(ARGV)
