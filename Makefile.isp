.PHONY: all
.PHONY: install
.PHONY: clean

ISP_PREFIX ?= /opt/isp/

all:
	stack build

install:
	stack install --local-bin-path=$(ISP_PREFIX)/bin/

clean:
	stack clean
