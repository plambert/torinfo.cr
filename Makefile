PREFIX ?= /usr/local
BIN_DIR = $(PREFIX)/bin

.PHONY: build install test format lint clean

build:
	shards build --error-trace

install: build
	install -d $(BIN_DIR)
	install bin/torinfo $(BIN_DIR)/torinfo

test:
	crystal spec -v --error-trace

format:
	crystal tool format

lint: format
	lib/ameba/bin/ameba src/ spec/

clean:
	rm -rf bin/ lib/
