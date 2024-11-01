
This repository holds an array of raw information, some referenced, that I've
collected over time.

There are scripts to turn the .info files into YAML and further scripts to then
process the YAML.

Scripts that hold classes rather than the main code are in scripts/Class* and
scripts that handle reading of non-YAML data are in scripts/Data*.

The remainder handle conversion of the raw data into various formats. Most of
the data is intended to be converted into mediawiki pages that make use of
InfoBox format. There are other conversion scripts though, such as
bus-module-to-mediawiki.rb that produces tables of known modules grouped by bus
and systems-yaml-to-os-release.rb that produces tables of systems along with
the range of supported operating systems for each (where known).

## History ##

I started to gather this information in the late 1980s, intending to turn it
into neatly formatted TeX pages. That never got very far but it meant that my
data initially started out as tables of text in almost-TeX. (Almost-TeX because
I never had time to actually run the stuff through TeX and produce printable
output).

After a while I abandoned the idea of TeX and changed to the .info format that
the data is in now. If YAML had been around back then perhaps I would have used
it as my raw information format, but it wasn't so now I start by converting the
.info format to YAML. Everything else uses the YAML as input.

The referencing has worked in a number of ways over the years, but I've not
documented the various ways, so I've lost track of how they worked :-) The
current format uses a set of "lref" (local references) per entry and then
refers to the appropriate one using a "vref". These references can be relied on
(meaning that I've actually drawn the data from the reference
document). Earlier refrences ("htref" and "uref") sometimes refer to a number
in a now lost list and sometimes refer to a specific document (which could be
followed up and added to the main list of references, but I haven't had time to
chase all of these up yet).
