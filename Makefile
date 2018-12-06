SYSTEMS += alpha
SYSTEMS += mips
SYSTEMS += pc
SYSTEMS += pdp11
SYSTEMS += vax

YAML_OUTPUT = bin/yaml

REFS = $(YAML_OUTPUT)/refs.yaml

PUBS = $(YAML_OUTPUT)/pubs.yaml

TAGS.SYSTEMS = scripts/systems-tags.yaml

SCRIPTS += scripts/DataPubTxt.rb
SCRIPTS += scripts/DataRefInfo.rb
SCRIPTS += scripts/DataSystemsInfo.rb
SCRIPTS += scripts/DataTags.rb
SCRIPTS += scripts/pub-txt-to-yaml.rb
SCRIPTS += scripts/refs-info-to-yaml.rb
SCRIPTS += scripts/systems-info-to-yaml.rb
SCRIPTS += scripts/systems-yaml-to-infobox-data.rb
SCRIPTS += scripts/systems-yaml-to-infobox-mediawiki.rb
SCRIPTS += scripts/systems-yaml-to-mediawiki.rb

GLOBAL_DEPENDENCIES += $(SCRIPTS)

# Variables above, rules below

all: build.tree

all: $(REFS)

all: $(PUBS)

all: $(foreach SYS,$(SYSTEMS),$(YAML_OUTPUT)/$(SYS).yaml)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).mediawiki.txt)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).infobox.mediawiki.txt)

all: $(foreach SYS,$(SYSTEMS),bin/infobox-$(SYS)-data.mediawiki.txt)

.PHONY: all

.PHONY: build.tree

build.tree:
	@mkdir -p bin
	@mkdir -p $(YAML_OUTPUT)

$(PUBS):  info/pubs-refs.txt $(GLOBAL_DEPENDENCIES)
	scripts/pub-txt-to-yaml.rb $< > $@

$(REFS):  info/refs.info $(GLOBAL_DEPENDENCIES)
	scripts/refs-info-to-yaml.rb $< > $@

$(YAML_OUTPUT)/alpha.yaml:  info/alpha.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb alpha $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/mips.yaml:  info/mips.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb decmips $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/pc.yaml:  info/pc.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb decpc $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/pdp11.yaml:  info/pdp11.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

$(YAML_OUTPUT)/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS) $(PUBS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) $(PUBS) > $@

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

clean:
	@rm -f bin/*

.PHONY: bin/info-data.bundle

bundle: bin/info-data.bundle

bin/info-data.bundle:
	git bundle create $@ master --
