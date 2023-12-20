require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname())

require "scripts/ClassItemWithReferenceKeys.rb"

require "scripts/ClassTrackLocalReferences.rb"

describe ItemWithReferenceKeys do

  global_refs = {
    "REF-01" => { "TITLE" => "TITLE-REF-01" },
    "REF-02" => { "TITLE" => "TITLE-REF-02" },
    "REF-03" => { "TITLE" => "TITLE-REF-03" },
    "REF-04" => { "TITLE" => "TITLE-REF-04" },
    "REF-05" => { "TITLE" => "TITLE-REF-05" }
  }

  # Test with no refs
  describe ".value" do
    context "data with no refs produces correct value" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1"]).value()).to eq("1")
      end
    end
  end

  describe ".refs" do
    context "data with no refs produces correct (empty) ref" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1"]).refs()).to eq([])
      end
    end
  end

  describe ".each_ref" do
    context "data with no refs produces correct each_ref" do
      it "returns true" do
        count = 0
        ItemWithReferenceKeys.new(["1"]).each_ref() {
          |r|
          count += 1
        }
        expect(count).to eq(0)
      end
    end
  end

  describe ".value_with_refs" do
    context "data with no refs produces correct value_with_refs" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["V"]).value_with_refs(TrackLocalReferences.new(), global_refs)).to eq("V")
      end
    end
  end
  
  # Test with one ref
  describe ".value" do
    context "data with one ref produces correct value" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1", :a]).value()).to eq("1")
      end
    end
  end

  describe ".refs" do
    context "data with one ref produces correct refs" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1", :a]).refs()).to eq([:a])
      end
    end
  end

  describe ".each_ref" do
    context "data with one ref produces correct each_ref" do
      it "returns true" do
        result = []
        count = 0
        ItemWithReferenceKeys.new(["1", :a]).each_ref() {
          |r|
          result << r
          count += 1
          expect(result.size()).to eq(count)
        }
        expect(count).to eq(1)
        expect(result).to eq([:a])
      end
    end
  end

  describe ".value_with_refs" do
    context "data with one refs produces correct value_with_refs" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["V", "REF-02"]).value_with_refs(TrackLocalReferences.new(), global_refs)).to eq("V [[#ref_1|[1]]]")
      end
    end
  end

  # Test with two refs
  describe ".value" do
    context "value with several refs produces correct value" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1", :a, :b]).value()).to eq("1")
      end
    end
  end

  describe ".item" do
    context "value with several refs produces correct refs" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["1", :a, :b]).refs()).to eq([:a, :b])
      end
    end
  end

  describe ".each_ref" do
    context "data with two refs produces correct each_ref" do
      it "returns true" do
        result = []
        count = 0
        ItemWithReferenceKeys.new(["1", :a, :b]).each_ref() {
          |r|
          result << r
          count += 1
          expect(result.size()).to eq(count)
        }
        expect(count).to eq(2)
        expect(result).to eq([:a, :b])
      end
    end
  end

  describe ".value_with_refs" do
    context "data with two refs produces correct value_with_refs" do
      it "returns true" do
        expect(ItemWithReferenceKeys.new(["V", "REF-02", "REF-05"]).value_with_refs(TrackLocalReferences.new(), global_refs)).to eq("V [[#ref_1|[1]]][[#ref_2|[2]]]")
      end
    end
  end

end
