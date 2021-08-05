require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname())

require "scripts/ClassTrackLocalReferences.rb"

describe TrackLocalReferences do

  refs = {"REF-1" => :ref_1, "REF-2" => :ref_2, "REF-3" => :ref_3, "REF-4" => :ref_4, "REF-5" => :ref_5}
  
  describe ".empty?" do
    context "freshly initialised" do
      it "returns true" do
        expect(TrackLocalReferences.new().empty?()).to eq(true)
      end
    end
  end
  
  describe ".build_local_refs" do
    context "build with a single ref" do
      it "returns that ref" do
        local_refs = TrackLocalReferences.new()
        local_refs.build_local_refs(["REF-2"], refs)
        result = nil
        local_refs.each_ref() { |r, value| result = value if result.nil?() }
        expect(result).to eq([1, :ref_2])
      end
    end
  end

  describe ".build_local_refs" do
    context "build with a three refs" do
      it "returns those refs in the correct order" do
        local_refs = TrackLocalReferences.new()
        local_refs.build_local_refs(["REF-2"], refs)
        local_refs.build_local_refs(["REF-5"], refs)
        local_refs.build_local_refs(["REF-4"], refs)
        result = []
        local_refs.each_ref() { |r, value| result << value }
        expect(result).to eq([[1, :ref_2], [2, :ref_5], [3, :ref_4]])
      end
    end
  end

  describe ".build_local_refs" do
    context "build with three refs, some repeated" do
      it "returns those refs (unduplicated) in the correct order" do
        local_refs = TrackLocalReferences.new()
        local_refs.build_local_refs(["REF-2"], refs)
        local_refs.build_local_refs(["REF-2"], refs)
        local_refs.build_local_refs(["REF-5"], refs)
        local_refs.build_local_refs(["REF-2"], refs)
        local_refs.build_local_refs(["REF-5"], refs)
        local_refs.build_local_refs(["REF-4"], refs)
        result = []
        local_refs.each_ref() { |r, value| result << value }
        expect(result).to eq([[1, :ref_2], [2, :ref_5], [3, :ref_4]])
      end
    end
  end

end
