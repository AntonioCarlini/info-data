SYSTEMS += alpha
SYSTEMS += mips
SYSTEMS += pc
SYSTEMS += pdp11
SYSTEMS += vax

REFS = yaml/refs.yaml

TAGS.SYSTEMS = scripts/systems-tags.yaml

# Variables above, rules below

all: yaml/refs.yaml

all: $(foreach SYS,$(SYSTEMS),yaml/$(SYS).yaml)

all: $(foreach SYS,$(SYSTEMS),bin/$(SYS).mediawiki.txt)

yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/alpha.yaml:  info/alpha.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/mips.yaml:  info/mips.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pc.yaml:  info/pc.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pdp11.yaml:  info/pdp11.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/alpha.mediawiki.txt: yaml/alpha.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/mips.mediawiki.txt: yaml/mips.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decmips $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pc.mediawiki.txt: yaml/pc.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/pdp11.mediawiki.txt: yaml/pdp11.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.mediawiki.txt: yaml/vax.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

clean:
	@rm yaml/*
	@rm bin/*

.PHONY: bin/info-data.bundle

bundle: bin/info-data.bundle

bin/info-data.bundle:
	git bundle create $@ master
