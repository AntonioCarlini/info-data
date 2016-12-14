all: yaml/refs.yaml

all: yaml/vax.yaml


yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

yaml/vax.yaml:  info/vax.info
	scripts/systems-info-to-yaml.rb vax $< > $@

clean:
	@rm yaml/*

