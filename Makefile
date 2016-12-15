all: yaml/refs.yaml

all: yaml/vax.yaml

all: bin/vax.mediawiki.txt


yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/vax.yaml:  info/vax.info
	scripts/systems-info-to-yaml.rb vax $< > $@

bin/vax.mediawiki.txt: yaml/vax.yaml
	@mkdir -p bin
	scripts/systems-yaml-to-mediawiki.rb $< > $@

clean:
	@rm yaml/*

