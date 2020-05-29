# archive.cr

![CI](https://github.com/hkalexling/archive.cr/workflows/CI/badge.svg)

`archive.cr` provides [libarchive](https://github.com/libarchive/libarchive) bindings for Crystal. Only a small subset of the libarchive functions are implemented, and currently only extraction is supported.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     archive:
       github: hkalexling/archive.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "archive"

# Extract all entries
Archive::File.open "file.zip" do |f|
  f.entries.map do |e|
    # Skip non-file entries
  	next unless e.info.file?

    filename = e.filename
    size = e.size
    file = File.new filename, "wb"
    file.write e.read
  end
end

# Extract a specific entry
Archive::File.open "file.zip" do |f|
    file = File.new "img.jpg", "wb"
    file.write f.read_entry "img.jpg"
end
```
