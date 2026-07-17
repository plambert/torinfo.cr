# torinfo

A Crystal shard and command line tool for reading BitTorrent files (`*.torrent`)

## Installation

Checkout the git repository and run `make install PREFIX=/path/to/bin`, which will build and install
the CLI for you.

## CLI Usage

Once `torinfo` is built and in your PATH, you can see help with:

```text
% torinfo --help
Usage: torinfo [options] <torrentfile...>

tool to read BitTorrent files

Options:
  --info                          Labelled human-readable text
  --table                         Aligned columns, one torrent per row
  --box                           Like --table with drawn borders
  --tsv                           Tab-separated values
  --csv                           Comma-separated values
  --json                          NDJSON, one object per torrent
  --yaml                          YAML, one document per torrent
  --bashv PREFIX                  Bash variable assignments for eval
  --bashf FUNCTION                Bash function call for eval
  --fields LIST                   Comma-separated fields to show (repeatable); replaces the default set
  --files                         Include the per-file listing
  --header                        Show a header row (default on for table/tsv/csv/box)
  --box-charset MODE              Box glyphs: --utf8, --ascii, or --auto (default) from the locale
  --size-unit UNIT                Size units: --human (default), --bytes, --kilobytes, --megabytes, --gigabytes
  --strftime FORMAT               Format timestamps with strftime FORMAT (visual formats)
  --unix-epoch                    Format timestamps as Unix epoch seconds (visual formats)

Positional arguments:
  <torrent_paths...>    BitTorrent files to read
```

### Output formats

`torinfo` renders each torrent in one of nine formats. With no format flag it
picks `--info` for a single torrent and `--table` for several:

```text
% torinfo *.torrent               # several torrents -> a table
 Size  Visibility  Created On            Name
1.02k  public      2024-01-01T00:00:00Z  ubuntu.iso.torrent
 3.5k  private     2024-01-01T00:00:00Z  album.torrent

% torinfo one.torrent             # a single torrent -> labelled info
Name: ubuntu.iso
Format: v1
Path: one.torrent
Hash: v1 36944055acf98ed2822d937ec0c32dd77f8d786b
...

% torinfo --box one.torrent       # --box draws borders (UTF-8 or ASCII by locale)
┌───────┬────────────┬──────────────────────┬────────────┐
│  Size │ Visibility │ Created On           │ Name       │
├───────┼────────────┼──────────────────────┼────────────┤
│ 1.02k │ public     │ 2024-01-01T00:00:00Z │ ubuntu.iso │
└───────┴────────────┴──────────────────────┴────────────┘

% torinfo --json one.torrent | jq .name
"ubuntu.iso"
```

The machine-oriented formats are `--json`, `--yaml`, `--tsv`, `--csv`, `--bashv`
and `--bashf`.

### Choosing fields

`--fields` takes a comma-separated list and may be repeated; it replaces the
format's default field set. Valid fields:

```text
name format path hash created-by created-on comment source
piece-count piece-size size visibility trackers
```

```text
% torinfo --fields size,name --fields visibility album.torrent
Size: 3.5k
Name: album
Visibility: private
```

The file listing is toggled independently with `--files` / `--no-files`, so it
does not change the default field set:

```text
% torinfo --files album.torrent          # default fields plus the files
...
% torinfo --fields size --files album.torrent   # only the size, plus the files
Size: 3.5k
Files:
  1. 1.0k  subdir/file1.txt
  2. 2.0k  subdir/file2.txt
  3.  500  other.txt
```

### Sizes

Sizes are humanized by default. `--bytes`, `--kilobytes`, `--megabytes` and
`--gigabytes` (or `--size-unit UNIT`) change the unit in the visual formats.
File-listing sizes are right-justified.

In the machine formats (`--json`, `--yaml`, `--tsv`, `--csv`, `--bashv`,
`--bashf`) the size is always reported in bytes; selecting a unit adds a
companion field alongside it (`size-gb` in json/yaml/tsv/csv, `size_gb` in
bash):

```text
% torinfo --json --fields size one.torrent
{"size":1024}
% torinfo --json --gigabytes --fields size one.torrent
{"size":1024,"size-gb":"0.0"}
```

### Bash integration

`--bashv` emits `eval`-able assignments; variable names are the prefix plus the
field name. A self-referential `<prefix>variables` array names every variable it
defined, so one `unset` cleans them all up:

```text
% eval "$(torinfo --bashv tfile_ file.torrent)"
% echo "$tfile_name"
ubuntu.iso
% printf '%8d %s\n' "${tfile_filesize[0]}" "${tfile_filename[0]}"
  123456 ubuntu.iso
% unset "${tfile_variables[@]}"   # remove every variable torinfo defined
```

`--bashf` emits a call to a function you supply, with the layout
`funcname <field args> -- <trackers> -- <files>`:

```text
% process_torrent() {
    local size="$1" visibility="$2" created_on="$3" name="$4"
    shift 4
    local trackers=() files=()
    [[ "$1" == -- ]] && shift
    while [[ "$1" != -- ]]; do trackers+=( "$1" ); shift; done
    shift
    while [[ $# -gt 0 ]]; do files+=( "$1 ($2 bytes)" ); shift 2; done
    printf '%s (%s bytes, %d files)\n' "$name" "$size" "${#files[@]}"
  }
% eval "$(torinfo --bashf process_torrent --files file.torrent)"
ubuntu.iso (123456 bytes, 3 files)
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

* [Paul M. Lambert](https://github.com/plambert) - creator and maintainer
