SYSTEMS += alpha
SYSTEMS += mips
SYSTEMS += pc
SYSTEMS += pdp11
SYSTEMS += vax

REFS = yaml/refs.yaml

TAGS.SYSTEMS = scripts/systems-tags.yaml

SCRIPTS += scripts/DataRefInfo.rb
SCRIPTS += scripts/DataSystemsInfo.rb
SCRIPTS += scripts/DataTags.rb
SCRIPTS += scripts/refs-info-to-yaml.rb
SCRIPTS += scripts/systems-info-to-yaml.rb
SCRIPTS += scripts/systems-yaml-to-infobox-data.rb
SCRIPTS += scripts/systems-yaml-to-infobox-mediawiki.rb
SCRIPTS += scripts/systems-yaml-to-mediawiki.rb

GLOBAL_DEPENDENCIES += $(SCRIPTS)

# Variables above, rules below

all: build.tree

all: yaml/refs.yaml

all: $(foreach SYS,$(SYSTEMS),yaml/$(SYS).yaml)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).mediawiki.txt)

all: bin/infobox-vax-data.mediawiki.txt

all: bin/vax.infobox.mediawiki.txt

.PHONY: all

.PHONY: build.tree

build.tree:
	@mkdir -p bin
	@mkdir -p generated
	@mkdir -p yaml

yaml/refs.yaml:  info/refs.info $(GLOBAL_DEPENDENCIES)
	scripts/refs-info-to-yaml.rb $< > $@

yaml/alpha.yaml:  info/alpha.info $(TAGS.SYSTEMS) $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/mips.yaml:  info/mips.info $(TAGS.SYSTEMS) $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pc.yaml:  info/pc.info $(TAGS.SYSTEMS) $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pdp11.yaml:  info/pdp11.info $(TAGS.SYSTEMS) $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/infobox-vax-data.mediawiki.txt: $(TAGS.SYSTEMS) ${GLOBAL_DEPENDENCIES}
	scripts/systems-yaml-to-infobox-data.rb vax $< $(TAGS.SYSTEMS) > $@

bin/alpha.mediawiki.txt: yaml/alpha.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/mips.mediawiki.txt: yaml/mips.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pc.mediawiki.txt: yaml/pc.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pdp11.mediawiki.txt: yaml/pdp11.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.mediawiki.txt: yaml/vax.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.infobox.mediawiki.txt: yaml/vax.yaml $(REFS) $(GLOBAL_DEPENDENCIES)
	scripts/systems-yaml-to-infobox-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

clean:
	@rm -f yaml/*
	@rm -f bin/*
	@rm -f generated/*

.PHONY: bin/info-data.bundle

bundle: bin/info-data.bundle

bin/info-data.bundle:
	git bundle create $@ master
