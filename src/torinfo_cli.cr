require "./torinfo"
require "./torinfo/cli"

begin
  Torinfo::CLI.new.run
rescue ex : ArgumentError
  STDERR.puts "torinfo: #{ex.message}"
  STDERR.puts "Run 'torinfo --help' for usage."
  exit 1
end
