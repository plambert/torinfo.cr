# torinfo

A Crystal shard and command line tool for reading BitTorrent files (`*.torrent`)

## Installation

Checkout the git repository and run `make install PREFIX=/path/to/bin`, which will build and install the CLI for you.

## CLI Usage

Once `torinfo` is built and in your PATH, you can see help with:

```
% torinfo --help
Usage: torinfo [options] <torrentfile...>

tool to read BitTorrent files

Options:
  --json                          Output JSON
  --text                          Output human-readable text (DEFAULT)
  --bashv PREFIX                  Output bash variable assignments suitable for eval
  --bashf FUNCTION                Output bash function call suitable for eval
  --raw                           Output values only (no labels); only valid with --text
  --strftime FORMAT               Format timestamps using strftime-style FORMAT
  --unix-epoch                    Format timestamps as seconds since Unix epoch
  --name                          Show the name
  --hash                          Show the info hash
  --created-by                    Show the creating program
  --created-on                    Show the creation timestamp
  --comment                       Show the comment
  --source                        Show the source
  --piece-count                   Show the piece count
  --piece-size                    Show the piece size
  --total-size                    Show the total size
  --visibility                    Show the visibility
  --trackers                      Show the trackers
  --files                         List the files

Positional arguments:
  <torrent_paths...>    BitTorrent files to read

--bashv and --bashf cannot be combined with field specifiers.
--raw is only valid with --text output.

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
% unset "${tfile_variables[@]}"   # remove every variable torinfo defined

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

## Shell completion

`torinfo` generates its own completion scripts for bash, zsh, and fish:

```sh
# Bash — eval in .bashrc, or write to a completions dir
eval "$(torinfo --shell-completion bash)"

# Zsh — write to a file on the fpath
torinfo --shell-completion zsh > _torinfo

# Fish
torinfo --shell-completion fish > ~/.config/fish/completions/torinfo.fish
```

`torinfo --version` prints the version, and `torinfo --help` lists every option.

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
