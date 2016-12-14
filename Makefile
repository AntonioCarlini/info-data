yaml/refs.yaml:  info/refs.info
	scripts/refs-info-to-yaml.rb $< > $@

default: refs.yaml
