SHELL=/usr/bin/env bash -o errexit

.PHONY: help build

export CONTAINER_ENGINE ?= podman

help:
	@echo "Targets:"
	@echo "  build -- build the docker image"

build:
	$(CONTAINER_ENGINE) build . -f Dockerfile

## --------------------------------------
## Release
## --------------------------------------
GO := $(shell type -P go)
# Use GOPROXY environment variable if set
GOPROXY := $(shell $(GO) env GOPROXY)
ifeq ($(GOPROXY),)
GOPROXY := https://proxy.golang.org
endif
export GOPROXY

RELEASE_TAG ?= $(shell git describe --abbrev=0 2>/dev/null)
RELEASE_NOTES_DIR := releasenotes

$(RELEASE_NOTES_DIR):
	mkdir -p $(RELEASE_NOTES_DIR)/

.PHONY: release-notes
release-notes: $(RELEASE_NOTES_DIR) $(RELEASE_NOTES)
	cd hack/tools && $(GO) run release/notes.go  --releaseTag=$(RELEASE_TAG) > $(realpath $(RELEASE_NOTES_DIR))/$(RELEASE_TAG).md
