# OsSupport helps to turn OS support properties into suitable "start of support" and "end of support"
# text with appropriate references.
#
# In general OS support has a starting version and a final version.
# As an example the VAX-11/750 was first supported by VMS V2.0.
# The last version to support this hardware was OpenVMS V6.2.
# 
# A slight wrinkle is that some hardware has a version that first supported the hardware and
# then a gap where the hardware was not supported, followed by a version where all subseqeunt
# versions provided support.
# An example of this would be the MicroVAX 3100 Model 85 which was first supported in
# VMS V5.5-2H4 but support was not included in OpenVMS V6.0. All versions from V6.1
# onwards provided full support.
#
# To allow for such wrinkles, this class accepts "early_support_version", "start_support_version"
# and "end_support_version" values.
# Supplying "early_support_version" without a valid "start_support_version" is unacceptable but currently ignored.
# All three values are optional (subject to the above proviso).
#
# All three values should be ItemWithReferenceKeys
# 
class OsSupport
  attr_reader  :os_begin_support
  attr_reader  :os_finish_support

  attr_reader  :early_support_version
  attr_reader  :start_support_version
  attr_reader  :end_support_version

  def initialize(early_support_version, start_support_version, end_support_version)
    @early_support_version = early_support_version
    @start_support_version = start_support_version
    @end_support_version = end_support_version
    @os_begin_support = nil
    @os_finish_support = nil
  end

  #+
  # Runs through the provided values and builds referenced "begin" and "finish" support strings.
  # "Finish" is straightforward and comes from "end". "Begin" is a combination of "early" and "start".
  def build_text(local_refs, global_refs)
    @os_begin_support = ""
    unless @early_support_version.nil?()
      ref_text = local_refs.build_local_refs(@early_support_version.refs(), global_refs)
      @os_begin_support = "#{@early_support_version.value()}#{ref_text}"
    end

    unless @start_support_version.nil?()
      ref_text = local_refs.build_local_refs(@start_support_version.refs(), global_refs)
      @os_begin_support += ", " unless os_begin_support.empty?()
      @os_begin_support += "#{@start_support_version.value()}#{ref_text}"
    end

    @os_finish_support = ""
    unless @end_support_version.nil?()
      ref_text = local_refs.build_local_refs(@end_support_version.refs(), global_refs)
      @os_finish_support = "#{@end_support_version.value()}#{ref_text}"
    end

    return self
  end
end
