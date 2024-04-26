#!/usr/bin/ruby -w

# Encapsulates a value that comes with a reference
# 'value' is the value to keep
# 'ref' is either a single reference or an array of references. Each reference will be a key in refs.yaml i.e. EK-KA655-TM-001 rather than 1 or 2.
class VariableWithReference

  attr_reader  :ref
  attr_reader  :value

  def initialize(value, ref)
    @value = value
    @ref = ref
  end

  def as_array()
    a = [ @value ]
    a << @ref unless @ref.nil?() || @ref.empty?()
    return a.flatten()
  end

end
