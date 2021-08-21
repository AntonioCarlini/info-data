# ItemWithReferenceKeys provides a way of turning the item-value-with-references from YAML into something
# that can be understood more intuitively.
#
# A property is allowed to have a value and a variable number of references, zero being an acceptable number of references.
# In YAML this is represented as an array where the first entry (which is required) is the property value and subsequent
# array entries (if any) are references, each being a text key to an entry in the refs.yaml data file.
#
# The purpose of this class is to accept that array and to supply the value and the refs as required.
#
class ItemWithReferenceKeys

  attr_reader  :value
  attr_reader  :refs

  def initialize(value_refs_array)
    @value = value_refs_array.shift()     # The first entry is the
    @refs = value_refs_array              # An array (possibly empty) of reference keys
  end

  # Allow walking of the ref keys
  def each_ref
    @refs.each() {
      |key|
      yield key
    }
  end
  
  # Convert to a string
  def value_with_refs(local_refs, global_refs)
    text = @value + local_refs.build_local_refs(@refs, global_refs)
  end
  
end

