all: yaml/refs.yaml

all: yaml/vax.yaml

all: yaml/alpha.yaml

all: yaml/pc.yaml

all: yaml/pdp11.yaml

all: bin/vax.mediawiki.txt

REFS = yaml/refs.yaml

TAGS.SYSTEMS = scripts/systems-tags.yaml

yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/alpha.yaml:  info/alpha.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb alpha $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pc.yaml:  info/pc.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb decpc $< $(TAGS.SYSTEMS) $(REFS) > $@

yaml/pdp11.yaml:  info/pdp11.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb pdp11 $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.mediawiki.txt: yaml/vax.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

clean:
	@rm yaml/*

