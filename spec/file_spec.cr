require "./spec_helper"

ARY     = [".hidden", "1.jpg", "2.jpg", "3.jpg", "dir", "hello world.jpg"]
ZIP_ARY = [".hidden", "1.jpg", "2.jpg", "3.jpg", "dir/", "hello world.jpg"]

describe Archive::File do
  it "handles RAR5", tags: "rar5" do
    # libarchive >= v3.4.0 is required
    Archive::File.open "spec/asset/test.cbr" do |f|
      f.entries.map { |e| e.filename }.sort.should eq ARY
    end
  end

  it "handles Zip" do
    Archive::File.open "spec/asset/test.cbz" do |f|
      f.entries.map { |e| e.filename }.sort.should eq ZIP_ARY
    end
  end

  it "raises on password protected archive" do
    Archive::File.open "spec/asset/pass.cbr" do |f|
      expect_raises Archive::Error do
        f.read_entry "1.jpg"
      end
    end
  end

  it "raises when reading directories" do
    Archive::File.open "spec/asset/test.cbr" do |f|
      expect_raises Archive::Error do
        f.read_entry "dir"
      end
    end
  end

  it "correctly reads entry content" do
    Archive::File.open "spec/asset/test.cbr" do |f|
      entry_data = f.read_entry "1.jpg"
      File.open "spec/asset/1.jpg" do |img|
        data = Bytes.new img.size
        img.read_fully? data
        data.should eq entry_data
      end
    end
  end

  it "handles archives with utf8 filenames" do
    Archive::File.open "spec/asset/😄.cbr" do |f|
      f.entries.map { |e| e.filename }.sort.should eq ARY
    end
  end

  it "handles archives with utf8 entry filenames" do
    Archive::File.open "spec/asset/utf8.cbr" do |f|
      f.entries[0].filename.should eq "😄"
    end
  end
end
