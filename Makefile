all: yaml/refs.yaml

all: yaml/vax.yaml

all: bin/vax.mediawiki.txt

REFS = yaml/refs.yaml

TAGS.SYSTEMS = scripts/systems-tags.yaml

yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/vax.yaml:  info/vax.info $(TAGS.SYSTEMS) $(REFS)
	scripts/systems-info-to-yaml.rb vax $< $(TAGS.SYSTEMS) $(REFS) > $@

bin/vax.mediawiki.txt: yaml/vax.yaml $(REFS)
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb $< $(REFS) > $@

clean:
	@rm yaml/*

