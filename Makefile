# SiteBlocker — convenience targets. All real work lives in Scripts/ (which call swiftc directly
# because this machine's SwiftPM manifest tooling is broken; see README).

.PHONY: all test integration check build icon app run clean

all: app

test:                 ## Build & run the unit test suite
	@bash Scripts/test.sh

integration:          ## Build & run the helper integration tests
	@bash Scripts/integration-test.sh

check: test integration   ## Run all tests

build:                ## Build the core lib, helper, and GUI executable
	@bash Scripts/build.sh

icon:                 ## Generate build/AppIcon.icns
	@bash Scripts/make-icon.sh

app: icon             ## Build and package build/SiteBlocker.app
	@bash Scripts/package-app.sh

run: app              ## Build, package, and launch the app
	@open build/SiteBlocker.app

clean:                ## Remove build artifacts
	@rm -rf build
