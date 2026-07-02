# Makefile for Jupyterlab extensions version 1.32
# changelog:
#   1.32 - use a project-local nodeenv at .nodeenv/ instead of overwriting the python
#          prefix via `nodeenv -p` (which used to fail with "Text file busy" when the
#          existing node binary was held open). PATH=.nodeenv/bin:$PATH is exported so
#          every target transparently picks up the pinned local node + npm + yarn.
#          install_dependencies now guards each install step - only what's missing
#          gets installed. mrproper removes .nodeenv too.
#   1.31 - mrproper now removes ui-tests/node_modules (Playwright browser binaries)
#   1.30 - check twine in check_dependencies, ensure publish doesn't fail on missing twine
#   1.29 - replace yarn with jlpm, add prettier format, auto-commit and push after publish
#   1.28 - initial versioned Makefile
# author: Stellars Henson <konrad.jelen@gmail.com>
# License: MIT Open Source License

.PHONY: build install clean uninstall publish dependencies mrproper increment_version install_dependencies check_dependencies upgrade help test
.DEFAULT_GOAL := help

# Project-local node environment - keeps node/npm/yarn pinned per project and out of
# the python prefix. Created by `install_dependencies` and torn down by `mrproper`.
NODEENV := $(CURDIR)/.nodeenv
export PATH := $(NODEENV)/bin:$(PATH)

# Read current version from package.json (only if node is available)
VERSION := $(shell command -v node >/dev/null 2>&1 && node -p "require('./package.json').version" || echo "0.0.0")

## increment project version
increment_version:
	@echo "Current version: $(VERSION)"
	@bash -c 'CURRENT_VERSION=$(VERSION); \
	IFS="." read -r major minor patch <<< "$$CURRENT_VERSION"; \
	NEW_PATCH=$$((patch + 1)); \
	NEW_VERSION="$$major.$$minor.$$NEW_PATCH"; \
	echo "New version: $$NEW_VERSION"; \
	sed -i "s/\"version\": \"$$CURRENT_VERSION\"/\"version\": \"$$NEW_VERSION\"/" package.json; '

## build packages
build: clean increment_version check_dependencies
	npm install
	jlpm install
	npx prettier --write package-lock.json package.json
	python -m build

## install package
install: build
	pip install dist/*.whl --force-reinstall

## run tests
test: check_dependencies
	jlpm test

## clean builds and installables
clean: uninstall  check_dependencies
	@command -v npm >/dev/null 2>&1 && npm run clean || true
	@command -v npm >/dev/null 2>&1 && npm run clean:labextension || true
	rm -rf dist lib || true

## uninstall package
uninstall:  check_dependencies
	pip uninstall -y dist/*.whl 2>/dev/null || true

## check if required dependencies are installed in the project-local nodeenv
check_dependencies:
	@echo "Checking dependencies..."
	@MISSING=""; \
	[ -x "$(NODEENV)/bin/node" ] || MISSING="$$MISSING node"; \
	[ -x "$(NODEENV)/bin/npm" ] || MISSING="$$MISSING npm"; \
	[ -x "$(NODEENV)/bin/yarn" ] || MISSING="$$MISSING yarn"; \
	python -m twine --version >/dev/null 2>&1 || MISSING="$$MISSING twine"; \
	if [ -n "$$MISSING" ]; then \
		echo "Missing dependencies:$$MISSING"; \
		echo "Installing missing dependencies..."; \
		$(MAKE) install_dependencies; \
	else \
		echo "All dependencies are installed."; \
	fi

## publish package to public repository
publish: check_dependencies install
	npm publish --access public
	python -m twine upload dist/*
	git add package.json package-lock.json
	git commit -m "chore: post-publish $$(node -p "require('./package.json').version") package metadata"
	git push

## install required build dependencies into the project-local nodeenv (only what's missing)
install_dependencies:
	@if ! python -m twine --version >/dev/null 2>&1; then \
		echo "Installing twine..."; \
		pip install twine; \
	fi
	@if [ ! -x "$(NODEENV)/bin/node" ] || [ ! -x "$(NODEENV)/bin/npm" ]; then \
		echo "Creating project-local node environment at $(NODEENV)..."; \
		python -c "import nodeenv" >/dev/null 2>&1 || pip install nodeenv; \
		nodeenv --node=lts --prebuilt "$(NODEENV)"; \
	fi
	@if [ ! -x "$(NODEENV)/bin/yarn" ]; then \
		echo "Installing yarn + rimraf into $(NODEENV)..."; \
		"$(NODEENV)/bin/npm" install -g yarn rimraf; \
	fi
	@echo "node:  $$($(NODEENV)/bin/node --version 2>/dev/null) ($(NODEENV)/bin/node)"
	@echo "npm:   $$($(NODEENV)/bin/npm --version 2>/dev/null)"
	@echo "yarn:  $$($(NODEENV)/bin/yarn --version 2>/dev/null)"

## upgrade all npm and yarn dependencies
upgrade: check_dependencies
	jlpm up

## cleanup all build and metabuild artefacts (including the project-local nodeenv)
mrproper: clean uninstall
	rm -rf node_modules .yarn ui-tests/node_modules .nodeenv || true

## prints the list of available commands
help:
	@echo ""
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' 
	@echo ""


# EOF

