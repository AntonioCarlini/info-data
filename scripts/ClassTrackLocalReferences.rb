# TrackLocalReferences assigns local references a number in the order that they are used.
#
# An entry might have:
#   **Def-lref{1} = ref{EK-A0371-OM.002}
#   **Def-lref{2} = ref{SOMETHING-UNUSED}
#   **Def-lref{3} = ref{CPU-UPGR-SPRING-1992}
#   **Def-lref{4} = ref{DECdirect-AUG91}
#
# If the references are used in the order ref{CPU-UPGR-SPRING-1992}, ref{EK-A0371-OM.002}, ref{DECdirect-AUG91}
# then in the final wiki page they will be listed as:
#   [1] ref{CPU-UPGR-SPRING-1992}
#   [2] ref{EK-A0371-OM.002}
#   [3] ref{DECdirect-AUG91}
#
# References may be used more than once, in which case they will be consistently labelled. The reference
# number is determined by the next available number on its first use.
#
class TrackLocalReferences

  def initialize
    @next_local_ref_index = 1
    @used_local_refs = {}   # Hash of index (int) => properties
  end

  # Create a single local ref.
  # If this is the first use, create it and add it to @used_local_refs
  # If it has already been assigned, look it up.
  # In either case, produce the reference text.
  #
  # ref_key will be "EK-A0371-OM.002" or "CPU-UPGR-SPRING-1992" or "DECdirect-AUG91"
  # ref_properties will be the corresponding entry properties from refs.yaml
  def build_single_ref(ref_key, ref_properties)
    ref_index = nil                         # No reference present, or invalid reference present
    reference = @used_local_refs[ref_key]
    if reference.nil?()
      @used_local_refs[ref_key] = [ @next_local_ref_index, ref_properties ]
      ref_index = @next_local_ref_index
      @next_local_ref_index += 1
    else
      ref_index = reference[0]
    end
    ref_text = "[[#ref_#{ref_index}|[#{ref_index}]]]"
  end

  # Build a list of references for this specific data entry.
  #
  # ref_keys will be an array of reference keys ["EK-A0371-OM.002", "CPU-UPGR-SPRING-1992", "DECdirect-AUG91"]
  # ref_properties will be the corresponding entry from refs.yaml
  def build_local_refs(ref_keys, refs)
    ref_text = ""
    ref_keys.each() {
      |ref_key|
      ref_text << self.build_single_ref(ref_key, refs[ref_key])
    }
    ref_text = " " + ref_text unless ref_text.empty?()
    return ref_text
  end

  # Helper function to determine if any local references were used at all
  def empty?()
    @used_local_refs.empty?()
  end
  
  # Perform an action for every local reference that was used
  def each_ref
    @used_local_refs.keys().each() {
      |key|
      yield [key, @used_local_refs[key]]
    }
  end
end
