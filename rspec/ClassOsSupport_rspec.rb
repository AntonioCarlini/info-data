require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname())

require "scripts/ClassOsSupport.rb"
require "scripts/ClassItemWithReferenceKeys.rb"
require "scripts/ClassTrackLocalReferences.rb"

describe OsSupport do

  global_refs = {
    "REF-01" => { "TITLE" => "TITLE-REF-01" },
    "REF-02" => { "TITLE" => "TITLE-REF-02" },
    "REF-03" => { "TITLE" => "TITLE-REF-03" },
    "REF-04" => { "TITLE" => "TITLE-REF-04" },
    "REF-05" => { "TITLE" => "TITLE-REF-05" }
  }

  # Test with only "start" supplied (with no ref)
  describe ".os_begin_support" do
    context "only start_support_version produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("start-ver")
      end
    end
  end

  describe ".os_finish_support" do
    context "only start_support_version produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("")
      end
    end
  end

  # Test with only "start" supplied (with one ref)
  describe ".os_begin_support" do
    context "only start_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver", "REF-01"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("start-ver [[#ref_1|[1]]]")
      end
    end
  end

  describe ".os_finish_support" do
    context "only start_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver", "REF-01"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("")
      end
    end
  end

  # Test with only "end" supplied (with no ref)
  describe ".os_begin_support" do
    context "only end_support_version produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, nil, ItemWithReferenceKeys.new(["end-ver"]), )
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("")
      end
    end
  end

  describe ".os_finish_support" do
    context "only end_support_version produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, nil, ItemWithReferenceKeys.new(["end-ver"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("end-ver")
      end
    end
  end

  # Test with only "end" supplied (with one ref)
  describe ".os_begin_support" do
    context "only end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, nil, ItemWithReferenceKeys.new(["end-ver", "REF-01"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("")
      end
    end
  end

  describe ".os_finish_support" do
    context "only end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, nil, ItemWithReferenceKeys.new(["end-ver", "REF-01"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("end-ver [[#ref_1|[1]]]")
      end
    end
  end

  # Test with both start and "end" supplied (with one ref)
  describe ".os_begin_support" do
    context "start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver", "REF-01"]), ItemWithReferenceKeys.new(["end-ver", "REF-02"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("start-ver [[#ref_1|[1]]]")
      end
    end
  end

  describe ".os_finish_support" do
    context "start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(nil, ItemWithReferenceKeys.new(["start-ver", "REF-01"]), ItemWithReferenceKeys.new(["end-ver", "REF-02"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("end-ver [[#ref_2|[2]]]")
      end
    end
  end


  # Test with both "early" and "start" supplied (with one ref each)
  describe ".os_begin_support" do
    context "start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(ItemWithReferenceKeys.new(["early-ver", "REF-01"]), ItemWithReferenceKeys.new(["start-ver", "REF-02"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("early-ver [[#ref_1|[1]]], start-ver [[#ref_2|[2]]]")
      end
    end
  end

  describe ".os_finish_support" do
    context "start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(ItemWithReferenceKeys.new(["early-ver", "REF-03"]), ItemWithReferenceKeys.new(["start-ver", "REF-04"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("")
      end
    end
  end

  # Test with both "early" and "start" supplied (with *same* ref each)
  describe ".os_begin_support" do
    context "start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(ItemWithReferenceKeys.new(["early-ver", "REF-03"]), ItemWithReferenceKeys.new(["start-ver", "REF-03"]), nil)
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("early-ver [[#ref_1|[1]]], start-ver [[#ref_1|[1]]]")
      end
    end
  end

  # Test with "early", "start" and "end" supplied (with a different ref each)
  describe ".os_begin_support" do
    context "early_start, start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(ItemWithReferenceKeys.new(["early-ver", "REF-03"]), ItemWithReferenceKeys.new(["start-ver", "REF-04"]), ItemWithReferenceKeys.new(["end-ver", "REF-05"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_begin_support()).to eq("early-ver [[#ref_1|[1]]], start-ver [[#ref_2|[2]]]")
      end
    end
  end

  describe ".os_finish_support" do
    context "early_start, start_support and end_support_version plus ref produces correct value" do
      it "returns true" do
        expect(OsSupport.new(ItemWithReferenceKeys.new(["early-ver", "REF-03"]), ItemWithReferenceKeys.new(["start-ver", "REF-04"]), ItemWithReferenceKeys.new(["end-ver", "REF-05"]))
                 .build_text(TrackLocalReferences.new(), global_refs).os_finish_support()).to eq("end-ver [[#ref_3|[3]]]")
      end
    end
  end
end
