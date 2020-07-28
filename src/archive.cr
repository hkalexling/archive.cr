require "./libarchive"

module Archive
  NULL = Pointer(LibC::Char).null

  alias Status = LibArchive::Status

  class Error < Exception
    getter message
    getter status
    getter code : Int32

    def initialize(reader : Reader)
      @status = reader.status
      @message = reader.error || ""
      @code = status.value
      super message
    end

    def initialize(@message)
      @status = Status::FATAL
      @code = status.value
      super message
    end
  end

  class Entry
    getter filename : String
    getter size : LibC::SizeT
    getter info : Crystal::System::FileInfo

    property file : File?

    def initialize(@filename, @size, @info)
    end

    def read
      file.not_nil!.read_entry filename
    end
  end

  private class Reader
    getter status : Status

    def initialize(filename : String, block_size = 10240)
      @a = LibArchive.archive_read_new
      LibArchive.archive_read_support_filter_all @a
      LibArchive.archive_read_support_format_all @a
      @status = LibArchive.archive_read_open_filename @a, filename, block_size
      raise?
    end

    def close
      LibArchive.archive_read_free @a
    end

    def self.open(filename : String, block_size = 10240, &)
      reader = self.new filename, block_size
      yield reader
      reader.close
    end

    def entries(&)
      loop do
        e = uninitialized LibArchive::ArchiveEntry
        @status = LibArchive.archive_read_next_header(@a, pointerof(e))
        break if @status == LibArchive::Status::EOF
        raise?

        size = LibArchive.archive_entry_size e
        char_ptr = LibArchive.archive_entry_pathname_utf8 e
        if char_ptr == NULL
          raise Error.new "Failed to retrieve entry filename. Got a null pointer."
        end
        name = String.new char_ptr

        stat = LibArchive.archive_entry_stat(e).value
        info = Crystal::System::FileInfo.new stat
        entry = Entry.new name, size, info

        yield entry
      end
    end

    def read_entry(filename : String, &)
      entries do |e|
        next unless e.filename == filename

        raise Error.new "Reading non-file entries is not allowed" unless e.info.file?

        buffer = Bytes.new e.size
        read_size = LibArchive.archive_read_data @a, buffer, e.size
        raise? if read_size < 0

        yield buffer
      end
    end

    def entries : Array(Entry)
      ary = [] of Entry
      entries { |e| ary.push e }
      ary
    end

    def error
      char_ptr = LibArchive.archive_error_string @a
      return nil if char_ptr == NULL
      String.new char_ptr
    end

    def raise?
      raise Error.new self if error
    end
  end

  class File
    def initialize(@filename : String, @block_size = 10240)
    end

    def self.open(filename : String, block_size = 10240, &)
      file = self.new filename, block_size
      yield file
    end

    private def reader(&)
      r = Reader.new @filename, @block_size
      yield r
    ensure
      r.close unless r.nil?
    end

    def entries
      ary = [] of Entry
      reader do |r|
        r.entries.map do |e|
          e.file = self
          ary.push e
        end
      end
      ary
    end

    def read_entry(filename : String)
      data = Bytes.empty
      reader do |r|
        r.read_entry filename do |buf|
          data = buf
        end
      end
      data
    end

    # Attemps to get read the first file entry. Raises if it failes.
    #   This is useful when checking the integrity of the archive.
    def check
      reader do |r|
        r.entries do |e|
          next unless e.info.file?
          e.file = self
          e.read
          break
        end
      end
    end
  end
end
