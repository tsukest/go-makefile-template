ROOT_PKG:=$(shell grep '^module' go.mod | cut -d ' ' -f 2)
GOVERSION:=$(shell go version)
GOOS:=$(word 1,$(subst /, ,$(lastword $(GOVERSION))))
GOARCH:=$(word 2,$(subst /, ,$(lastword $(GOVERSION))))
VERSION:=$(shell git describe --always)
REVISION:=$(shell git rev-parse --short HEAD)
BIN_DIR:=bin
RELEASE_DIR:=release
ARTIFACTS_DIR:=$(RELEASE_DIR)/artifacts/$(VERSION)
LDFLAGS:=-extldflags "-static" -s -w -X main.version="$(VERSION)-$(REVISION)"
GO_FILES:=$(shell find . -type f -name '*.go' -not -name '*_test.go' -not -name '*_mock.go' -print)
BUILD_TARGETS:= \
	build-linux-amd64
RELEASE_TARGETS=\
	release-linux-amd64

.PHONY: version fmt check mock test build $(BUILD_TARGETS) rebuild release-targz $(RELEASE_TARGETS) clean

version:
	@echo -n $(VERSION)

fmt:
	@go fmt ./...

check:
	@gofmt -l $(shell find . -name "*.go") | xargs -I{} sh -c 'test -z {} || echo "{}"; exit 1'
	@go vet ./...
	@golint -set_exit_status ./...

mock: \
	generator/file/XXX_mock.go \

%_mock.go: %.go
	mockgen -destination=$@ -source=$< -package=$(shell basename $(dir $<))

test:
	@go test ./...

build-linux-amd64:
	@$(MAKE) build GOOS=linux GOARCH=amd64

build: $(BIN_DIR)/XXX_$(GOOS)_$(GOARCH)/XXX

$(BIN_DIR)/XXX_$(GOOS)_$(GOARCH)/XXX: $(GO_FILES) .git/HEAD
	go build -o $@ -tags netgo -installsuffix netgo -ldflags '$(LDFLAGS)' $(ROOT_PKG)/cmd/$(notdir $@)

rebuild: clean build

$(ARTIFACTS_DIR):
	@mkdir -p $(ARTIFACTS_DIR)

release-linux-amd64: build-linux-amd64
	@$(MAKE) release-targz GOOS=linux GOARCH=amd64

release-targz: \
	$(ARTIFACTS_DIR) \
	$(ARTIFACTS_DIR)/XXX.$(VERSION).$(GOOS)-$(GOARCH).tar.gz

$(ARTIFACTS_DIR)/XXX.$(VERSION).$(GOOS)-$(GOARCH).tar.gz: $(BIN_DIR)/XXX_$(GOOS)_$(GOARCH)/XXX
	tar -czf $@ -C $(dir $<) $(notdir $<)

clean:
	-@rm -r $(BIN_DIR)/*
	-@rm -r $(RELEASE_DIR)/*
