MONITORS += monitors

PRINTERS += printers

STORAGE += disks-dssi
STORAGE += disks-ide
STORAGE += disks-massbus
STORAGE += disks-misc
STORAGE += disks-scsi
STORAGE += disks-sdi
STORAGE += disks-st506
STORAGE += optical-misc
STORAGE += optical-scsi
STORAGE += tapes-dssi
STORAGE += tapes-massbus
STORAGE += tapes-misc
STORAGE += tapes-scsi
STORAGE += tapes-sti

SYSTEMS += alpha
SYSTEMS += mips
SYSTEMS += pc
SYSTEMS += pdp11
SYSTEMS += vax

TERMINALS += terminals

ENTRIES += $(MONITORS)
ENTRIES += ${PRINTERS}
ENTRIES += ${STORAGE}
ENTRIES += ${SYSTEMS}
ENTRIES += ${TERMINALS}

YAML_OUTPUT = bin/yaml

REFS = $(YAML_OUTPUT)/refs.yaml

PUBS = $(YAML_OUTPUT)/pubs.yaml

TAGS.MONITORS = scripts/monitors-tags.yaml
TAGS.PRINTERS = scripts/printers-tags.yaml
TAGS.STORAGE = scripts/storage-tags.yaml
TAGS.SYSTEMS = scripts/systems-tags.yaml
TAGS.TERMINALS = scripts/terminals-tags.yaml

SCRIPTS += scripts/ClassTrackLocalReferences.rb
SCRIPTS += scripts/DataEntriesInfo.rb
SCRIPTS += scripts/DataPubTxt.rb
SCRIPTS += scripts/DataRefInfo.rb
SCRIPTS += scripts/DataStorageInfo.rb
SCRIPTS += scripts/DataSystemsInfo.rb
SCRIPTS += scripts/DataTags.rb
SCRIPTS += scripts/VariableWithReference.rb
SCRIPTS += scripts/entries-info-to-yaml.rb
SCRIPTS += scripts/pub-txt-to-yaml.rb
SCRIPTS += scripts/refs-info-to-yaml.rb
SCRIPTS += scripts/storage-info-to-yaml.rb
SCRIPTS += scripts/systems-info-to-yaml.rb
SCRIPTS += scripts/systems-yaml-to-infobox-data.rb
SCRIPTS += scripts/systems-yaml-to-infobox-mediawiki.rb
SCRIPTS += scripts/systems-yaml-to-mediawiki.rb
SCRIPTS += scripts/systems-yaml-to-os-release.rb

GLOBAL_DEPENDENCIES += $(SCRIPTS)

# Variables above, rules below

all: build.tree

all: $(REFS)

all: $(PUBS)

all: $(foreach ENT,$(ENTRIES),$(YAML_OUTPUT)/$(ENT).yaml)

all: $(foreach ENT,$(ENTRIES),bin/$(ENT).infobox.mediawiki.txt)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).mediawiki.txt)

all: $(foreach SYS,$(SYSTEMS),bin/infobox-$(SYS)-data.mediawiki.txt)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).os-release.txt)

.PHONY: all

.PHONY: build.tree

build.tree:
	@mkdir -p bin
	@mkdir -p $(YAML_OUTPUT)

$(PUBS):  info/pubs-refs.txt $(GLOBAL_DEPENDENCIES)
	scripts/pub-txt-to-yaml.rb $< > $@

$(REFS):  info/refs.info $(GLOBAL_DEPENDENCIES)
	scripts/refs-info-to-yaml.rb $< > $@

# systems -> YAML
$(YAML_OUTPUT)/alpha.yaml:  info/alpha.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb alpha $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/mips.yaml:  info/mips.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb decmips $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/pc.yaml:  info/pc.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb decpc $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/pdp11.yaml:  info/pdp11.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

# systems -> infobox-data
bin/infobox-alpha-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb alpha $(TAGS.SYSTEMS) > $@

bin/infobox-mips-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb decmips $(TAGS.SYSTEMS) > $@

bin/infobox-pc-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb decpc $(TAGS.SYSTEMS) > $@

bin/infobox-pdp11-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb pdp11 $(TAGS.SYSTEMS) > $@

bin/infobox-vax-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb vax $(TAGS.SYSTEMS) > $@

# systems -> mediawiki
bin/alpha.mediawiki.txt: $(YAML_OUTPUT)/alpha.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/mips.mediawiki.txt: $(YAML_OUTPUT)/mips.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pc.mediawiki.txt: $(YAML_OUTPUT)/pc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pdp11.mediawiki.txt: $(YAML_OUTPUT)/pdp11.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.mediawiki.txt: $(YAML_OUTPUT)/vax.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

# systems -> infobox-mediawiki
bin/alpha.infobox.mediawiki.txt: $(YAML_OUTPUT)/alpha.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/mips.infobox.mediawiki.txt: $(YAML_OUTPUT)/mips.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pc.infobox.mediawiki.txt: $(YAML_OUTPUT)/pc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pdp11.infobox.mediawiki.txt: $(YAML_OUTPUT)/pdp11.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.infobox.mediawiki.txt: $(YAML_OUTPUT)/vax.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/alpha.os-release.txt: $(YAML_OUTPUT)/alpha.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-os-release.rb alpha $< $(REFS) > $@

bin/mips.os-release.txt: $(YAML_OUTPUT)/mips.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-os-release.rb decmips $< $(REFS) > $@

bin/pc.os-release.txt: $(YAML_OUTPUT)/pc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-os-release.rb pc $< $(REFS) > $@

bin/pdp11.os-release.txt: $(YAML_OUTPUT)/pdp11.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-os-release.rb pdp11 $< $(REFS) > $@

bin/vax.os-release.txt: $(YAML_OUTPUT)/vax.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-os-release.rb vax $< $(REFS) > $@

# storage -> YAML
$(YAML_OUTPUT)/disks-dssi.yaml:  info/disks-dssi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb dssi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-ide.yaml:  info/disks-ide.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb ide $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-massbus.yaml:  info/disks-massbus.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb massbus $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-misc.yaml:  info/disks-misc.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb misc $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-scsi.yaml:  info/disks-scsi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb scsi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-sdi.yaml:  info/disks-sdi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb sdi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/disks-st506.yaml:  info/disks-st506.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb st506 $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/optical-misc.yaml:  info/optical-misc.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb misc $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/optical-scsi.yaml:  info/optical-scsi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb scsi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/tapes-dssi.yaml:  info/tapes-dssi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb dssi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/tapes-massbus.yaml:  info/tapes-massbus.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb massbus $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/tapes-misc.yaml:  info/tapes-misc.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb misc $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/tapes-scsi.yaml:  info/tapes-scsi.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb scsi $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/tapes-sti.yaml:  info/tapes-sti.info $(TAGS.STORAGE) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb sti $< $(TAGS.STORAGE) $(REFS) $(PUBS) > $@

# storage -> infobox-mediawiki
bin/disks-dssi.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-dssi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-ide.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-ide.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-massbus.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-massbus.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-misc.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-misc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-scsi.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-scsi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-sdi.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-sdi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/disks-st506.infobox.mediawiki.txt: $(YAML_OUTPUT)/disks-st506.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/optical-misc.infobox.mediawiki.txt: $(YAML_OUTPUT)/optical-misc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/optical-scsi.infobox.mediawiki.txt: $(YAML_OUTPUT)/optical-scsi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/tapes-dssi.infobox.mediawiki.txt: $(YAML_OUTPUT)/tapes-dssi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/tapes-massbus.infobox.mediawiki.txt: $(YAML_OUTPUT)/tapes-massbus.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/tapes-misc.infobox.mediawiki.txt: $(YAML_OUTPUT)/tapes-misc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/tapes-scsi.infobox.mediawiki.txt: $(YAML_OUTPUT)/tapes-scsi.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

bin/tapes-sti.infobox.mediawiki.txt: $(YAML_OUTPUT)/tapes-sti.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/storage-yaml-to-infobox-mediawiki.rb Disk $< $(TAGS.STORAGE) $(REFS) > $@

# terminals -> YAML
$(YAML_OUTPUT)/terminals.yaml:  info/terminals.info $(TAGS.TERMINALS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb decvt $< $(TAGS.TERMINALS) $(REFS) $(PUBS) > $@

bin/terminals.infobox.mediawiki.txt: $(YAML_OUTPUT)/terminals.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/entry-yaml-to-infobox-mediawiki.rb Terminal $< $(TAGS.TERMINALS) $(REFS) > $@

# monitors -> YAML
$(YAML_OUTPUT)/monitors.yaml:  info/monitors.info $(TAGS.MONITORS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb decvt $< $(TAGS.MONITORS) $(REFS) $(PUBS) > $@

bin/monitors.infobox.mediawiki.txt: $(YAML_OUTPUT)/monitors.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/entry-yaml-to-infobox-mediawiki.rb Terminal $< $(TAGS.MONITORS) $(REFS) > $@

# printers -> YAML
$(YAML_OUTPUT)/printers.yaml:  info/printers.info $(TAGS.PRINTERS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb decvt $< $(TAGS.PRINTERS) $(REFS) $(PUBS) > $@

bin/printers.infobox.mediawiki.txt: $(YAML_OUTPUT)/printers.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/entry-yaml-to-infobox-mediawiki.rb Printer $< $(TAGS.PRINTERS) $(REFS) > $@

# test data
$(YAML_OUTPUT)/test.yaml:  info/test.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/entries-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

clean:
	@rm -f bin/*

.PHONY: bin/info-data.bundle

bundle: bin/info-data.bundle

bin/info-data.bundle:
	git bundle create $@ master --
