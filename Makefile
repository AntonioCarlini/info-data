all: yaml/refs.yaml

all: yaml/vax.yaml

all: bin/vax.mediawiki.txt

REFS = yaml/refs.yaml

yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/vax.yaml:  info/vax.info $(REFS)
	scripts/systems-info-to-yaml.rb vax $< $(REFS) > $@

bin/vax.mediawiki.txt: yaml/vax.yaml
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb $< > $@

clean:
	@rm yaml/*

