# torinfo

A Crystal shard and command line tool for reading BitTorrent files (`*.torrent`)

## Installation

Checkout the git repository and run `make install PREFIX=/path/to/bin`, which will build and install the CLI for you.

## CLI Usage

Once `torinfo` is built and in your PATH, you can see help with:

```
% torinfo --help
torinfo - tool to read BitTorrent files

Usage: torinfo [options] <torrentfile...>

Options

  --help, -h                      Show this help
  --files                         List the files

  --name, --hash, --created-by, 
  --created-on, --comment,
  --source, --piece-count,
  --piece-size, --total-size,
  --visibility, --trackers        Show one or more fields

  --text                          Output values as human-readable text (DEFAULT)
  --bashv PREFIX                  Output bash variable assignments suitable for eval
  --bashf FUNCTION                Output bash function call suitable for eval
  --json                          Output JSON

% torinfo --json file.torrent | jq .name
"The Name of This BitTorrent File.txt"

% torinfo --name --hash file.torrent
Name: The Name of This BitTorrent File.txt
Hash: v1 36944055acf98ed2822d937ec0c32dd77f8d786b

% torinfo --visibility file.torrent
Visibility: private

% eval "$(torinfo --bashv tfile_ file.torrent)"
% echo "$tfile_name"
The Name of This BitTorrent File.txt
% printf '%8d %s\n' "${tfile_filesize[0]}" "${tfile_filename[0]}"
  123456 The Name of This BitTorrent File.txt

% process_torrent() {
    local name="$1" hash="$2" created_by="$3" created_on="$4" comment="$5"
    local source="$6" piece_count="$7" piece_size="$8" total_size="$9"
    local visibility="$10" trackers=() file_names=() file_sizes=()
    shift 10
    while [[ $# -gt 0 ]] && [[ "$1" != -- ]]; do
      trackers+=( "$1" )
      shift
    done
    [[ "$1" == -- ]] && shift
    while [[ $# -gt 0 ]]; do
      file_names+=( "$1" )
      file_sizes+=( "$2" )
      shift 2
    done

    # do something with that info
    printf '%s (%d bytes, %d files)\n' "$name" "$total_size" "${#file_names[*]}"
  }
% eval "$(torinfo --bashf process_torrent file.torrent)"
The Name of This BitTorrent File.txt (123456 bytes, 3 files)
```

## Shard Usage

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     torinfo:
       github: plambert/torinfo.cr
   ```

2. Run `shards install`

3. In your code:

```crystal
require "torinfo"
```

## Contributing

1. Fork it (<https://github.com/plambert/torinfo.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Paul M. Lambert](https://github.com/plambert) - creator and maintainer
