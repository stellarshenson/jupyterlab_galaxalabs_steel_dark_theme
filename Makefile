# Makefile for Jupyterlab extensions version 1.48
# changelog:
#   1.48 - mrproper removes tmp, logs, .venv, graphify-out, coverage and .pytest_cache too; install and publish are .NOTPARALLEL, the guard jupyterlab_vscode_icons_extension carried locally.
#   1.47 - increment_version takes BUMP none|patch|minor|major; none leaves the version unchanged.
#   1.46 - increment_version also writes the version into package-lock.json, in the text, and publish stages it.
#   1.45 - install adds every optional-dependencies group of pyproject.toml in a second pip run without --force-reinstall.
#   1.44 - check_dependencies reports a missing pytest when the package has tests/, and install_dependencies installs the test extras.
#   1.43 - the auth gate in test loads the source tree, not the last installed wheel.
#   1.42 - increment_version moves from publish onto install, so every make install raises the patch version and publish raises it once.
#   1.41 - increment_version moves off build onto publish; publish gains test; the metadata commit and push happen before either registry; npm install and package-lock.json are dropped.
#   1.40 - publish stages yarn.lock in the post-publish commit.
#   1.39 - upgrade reports with jlpm npm audit --recursive instead of npm audit fix --force, which rewrote @jupyterlab ranges to 0.x and the lockfile to Yarn 1 format.
#   1.38 - keep python -m build as the build command, approve blocked npm install scripts, and assert dist/ holds a wheel and an sdist before the npm push.
#   1.37 - pin the global install prefix to the nodeenv when installing yarn and rimraf.
#   1.36 - test runs the Python suite too when the package has tests/, not just jlpm.
#   1.35 - resolve node and npm from the project-local nodeenv via $(NODE) and $(NPM), and read VERSION lazily.
#   1.34 - build formats the lockfiles with jlpm prettier instead of npx prettier.
#   1.33 - check_dependencies treats a missing node_modules as missing, and install_dependencies runs jlpm install.
#   1.32 - use a project-local nodeenv at .nodeenv/ instead of overwriting the python prefix with nodeenv -p; mrproper removes it.
#   1.31 - mrproper also removes ui-tests/node_modules.
#   1.30 - check twine in check_dependencies.
#   1.29 - replace yarn with jlpm, add prettier format, commit and push after publish.
#   1.28 - initial versioned Makefile.
# author: Stellars Henson <konrad.jelen+github@gmail.com>
# License: MIT Open Source License

.PHONY: build install clean uninstall publish dependencies mrproper increment_version install_dependencies check_dependencies upgrade help test
.DEFAULT_GOAL := help

# Tests must finish before install, and the version must move before build,
# including when the caller supplies -j.
.NOTPARALLEL: install publish

# Project-local node environment - keeps node/npm/yarn pinned per project and out of
# the python prefix. Created by `install_dependencies` and torn down by `mrproper`.
NODEENV := $(CURDIR)/.nodeenv
NODE := $(NODEENV)/bin/node
NPM := $(NODEENV)/bin/npm
export PATH := $(NODEENV)/bin:$(PATH)

# Which part of the version `increment_version` raises: none, patch, minor or major.
BUMP ?= patch

# Read the current version from package.json using the project-local node only.
# Deliberately lazy (`=`, not `:=`): a parse-time read happens before check_dependencies
# has created the nodeenv, and an ambient node on PATH would silently mask that.
VERSION = $(shell $(NODE) -p "require('./package.json').version" 2>/dev/null)

# Python package name, taken from the labextension output dir. Lazy for the same
# reason as VERSION: $(NODE) does not exist until check_dependencies has run.
PYTHON_NAME = $(shell $(NODE) -p "require('./package.json').jupyterlab.outputDir.split('/')[0]" 2>/dev/null)

# Dependencies whose install scripts npm must be allowed to run. npm >= 11.6 blocks
# lifecycle scripts until approved, recording each approval in package.json under
# "allowScripts". Space-separated; extend per project.
ALLOW_SCRIPTS_PKGS := @fortawesome/fontawesome-free

# package-lock.json is edited in place, not parsed and written back: a rewrite with a
# fixed indent would re-indent every line of a lockfile that uses another indent.
## increment project version
increment_version: check_dependencies
	@CURRENT_VERSION="$(VERSION)"; \
	if [ -z "$$CURRENT_VERSION" ]; then \
		echo "increment_version: cannot read version from package.json via $(NODE)" >&2; \
		exit 1; \
	fi; \
	echo "Current version: $$CURRENT_VERSION"; \
	MAJOR="$${CURRENT_VERSION%%.*}"; \
	REST="$${CURRENT_VERSION#*.}"; \
	MINOR="$${REST%%.*}"; \
	PATCH="$${REST#*.}"; \
	case "$(BUMP)" in \
		none) NEW_VERSION="$$CURRENT_VERSION" ;; \
		patch) NEW_VERSION="$$MAJOR.$$MINOR.$$((PATCH + 1))" ;; \
		minor) NEW_VERSION="$$MAJOR.$$((MINOR + 1)).0" ;; \
		major) NEW_VERSION="$$((MAJOR + 1)).0.0" ;; \
		*) echo "increment_version: BUMP must be none, patch, minor or major" >&2; exit 1 ;; \
	esac; \
	sed -i "s/\"version\": \"$$CURRENT_VERSION\"/\"version\": \"$$NEW_VERSION\"/" package.json; \
	if ! grep -q "\"version\": \"$$NEW_VERSION\"" package.json; then \
		echo "increment_version: package.json still reports $$CURRENT_VERSION - not bumped" >&2; \
		exit 1; \
	fi; \
	if [ -f package-lock.json ]; then \
		$(NODE) -e 'const fs = require("fs"), v = process.argv[1]; let n = 0; const s = fs.readFileSync("package-lock.json", "utf8").replace(/"version": "[^"]*"/g, (m) => (n++ < 2 ? `"version": "$${v}"` : m)); const d = JSON.parse(s); if (d.version !== v || d.packages[""].version !== v) { console.error("increment_version: the first two version fields of package-lock.json are not the package version - not bumped"); process.exit(1); } fs.writeFileSync("package-lock.json", s);' "$$NEW_VERSION" || exit 1; \
	fi; \
	echo "New version: $$NEW_VERSION"

# `python -m build` is the whole build. Its hatch-jupyter-builder hook runs the
# `build_cmd` from pyproject.toml (build:prod = tsc + labextension) and then emits the
# sdist and wheel into dist/, which install and publish both read. Do not swap in a
# bare `jupyter-builder build`: it emits no distribution at all, and after `clean` it
# aborts with "Cannot find module lib/index.js" because it never runs tsc.
## build packages
build: clean check_dependencies
	jlpm install
	jlpm prettier
	python -m build

# The wheel brings its runtime dependencies. The second pip run adds every
# optional-dependencies group of pyproject.toml (`dev`, `test`, ...): pip sees the
# wheel it has just installed, leaves it alone and installs only what a group still
# lacks. It has no --force-reinstall, which would reinstall jupyterlab and its whole
# dependency tree on every build. A pyproject.toml that cannot be read stops the target.
## install package with its optional dependencies - raises the patch version first, so the build carries the new one
install: increment_version build
	pip install dist/*.whl --force-reinstall
	@EXTRAS="$$(python -c "import tomllib; print(','.join(tomllib.load(open('pyproject.toml', 'rb')).get('project', {}).get('optional-dependencies', {})))")" || exit 1; \
	if [ -n "$$EXTRAS" ]; then \
		echo "Installing the optional dependencies [$$EXTRAS]..."; \
		pip install "$$(ls dist/*.whl)[$$EXTRAS]"; \
	fi

## run tests
test: check_dependencies
	jlpm test
	@if [ -d "$(PYTHON_NAME)/tests" ]; then \
		pytest -vv -r ap; \
	else \
		echo "test: no $(PYTHON_NAME)/tests directory - skipping pytest"; \
	fi
	@if [ -f ".github/scripts/check_auth.py" ] && [ -d "$(PYTHON_NAME)/tests" ]; then \
		echo "Checking every endpoint requires authentication..."; \
		PYTHONPATH=$(CURDIR) python .github/scripts/check_auth.py; \
	else \
		echo "test: no .github/scripts/check_auth.py - skipping the auth gate"; \
	fi

## clean builds and installables
clean: uninstall  check_dependencies
	@[ -x "$(NPM)" ] && $(NPM) run clean || true
	@[ -x "$(NPM)" ] && $(NPM) run clean:labextension || true
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
	python -m build --version >/dev/null 2>&1 || MISSING="$$MISSING build"; \
	command -v jlpm >/dev/null 2>&1 || MISSING="$$MISSING jlpm"; \
	{ [ -d node_modules ] && [ -n "$$(ls -A node_modules 2>/dev/null)" ]; } || MISSING="$$MISSING node_modules"; \
	{ [ ! -d "$(PYTHON_NAME)/tests" ] || python -m pytest --version >/dev/null 2>&1; } || MISSING="$$MISSING pytest"; \
	if [ -n "$$MISSING" ]; then \
		echo "Missing dependencies:$$MISSING"; \
		echo "Installing missing dependencies..."; \
		$(MAKE) install_dependencies; \
	else \
		echo "All dependencies are installed."; \
	fi

# Order is load-bearing. The version is raised once, by install. test runs before
# install, so a red suite stops the release before the version moves. The commit
# and push happen before either registry is written to: a failure there costs nothing,
# whereas npm permanently consumes a version it has accepted.
## publish package to npm and PyPI
publish: check_dependencies test install
	@ls dist/*.whl >/dev/null 2>&1 && ls dist/*.tar.gz >/dev/null 2>&1 || { \
		echo "publish: dist/ holds no wheel or sdist - run make build first" >&2; \
		exit 1; \
	}
	git add package.json yarn.lock $(wildcard package-lock.json)
	git commit -m "chore: release $$($(NODE) -p "require('./package.json').version") package metadata"
	git push
	$(NPM) publish --access public
	@python -m twine upload dist/* || { \
		echo "publish: npm holds $$($(NODE) -p "require('./package.json').version") and PyPI does not." >&2; \
		echo "Do NOT re-run publish - it would consume the next version on npm too." >&2; \
		echo "Fix the credentials, then run: python -m twine upload dist/*" >&2; \
		exit 1; \
	}

## install required build dependencies into the project-local nodeenv (only what's missing)
install_dependencies:
	@if ! python -m twine --version >/dev/null 2>&1; then \
		echo "Installing twine..."; \
		pip install twine; \
	fi
	@if ! python -m build --version >/dev/null 2>&1; then \
		echo "Installing build..."; \
		pip install build; \
	fi
	@if ! command -v jlpm >/dev/null 2>&1; then \
		echo "Installing jupyter_builder (supplies jlpm)..."; \
		pip install jupyter_builder; \
	fi
	@if [ ! -x "$(NODEENV)/bin/node" ] || [ ! -x "$(NODEENV)/bin/npm" ]; then \
		echo "Creating project-local node environment at $(NODEENV)..."; \
		python -c "import nodeenv" >/dev/null 2>&1 || pip install nodeenv; \
		nodeenv --node=lts --prebuilt "$(NODEENV)"; \
	fi
	@if [ ! -x "$(NODEENV)/bin/yarn" ]; then \
		echo "Installing yarn + rimraf into $(NODEENV)..."; \
		"$(NODEENV)/bin/npm" install -g --prefix "$(NODEENV)" yarn rimraf; \
	fi
	@if [ ! -d node_modules ] || [ -z "$$(ls -A node_modules 2>/dev/null)" ]; then \
		echo "Installing project node_modules (jlpm install)..."; \
		jlpm install; \
	fi
	@if [ -d "$(PYTHON_NAME)/tests" ] && ! python -m pytest --version >/dev/null 2>&1; then \
		echo "Installing the test extras from pyproject.toml (pytest)..."; \
		python -c "import tomllib; print('\n'.join(tomllib.load(open('pyproject.toml', 'rb')).get('project', {}).get('optional-dependencies', {}).get('test', [])))" \
			| xargs -r -d '\n' pip install; \
	fi
	@for pkg in $(ALLOW_SCRIPTS_PKGS); do \
		if $(NPM) install-scripts approve "$$pkg" >/dev/null 2>&1; then \
			echo "install scripts approved: $$pkg"; \
		else \
			echo "install scripts not approved: $$pkg (absent from the tree, or npm < 11.6)"; \
		fi; \
	done
	@echo "node:  $$($(NODEENV)/bin/node --version 2>/dev/null) ($(NODEENV)/bin/node)"
	@echo "npm:   $$($(NODEENV)/bin/npm --version 2>/dev/null)"
	@echo "yarn:  $$($(NODEENV)/bin/yarn --version 2>/dev/null)"

# `npm audit fix --force` accepts breaking changes and downgrades, so review the diff to
# package.json and the lockfiles after every upgrade. It exits 1 whenever any advisory
# stays unfixed - the normal outcome - hence the `|| true` that keeps the target green.
## upgrade all npm and yarn dependencies
upgrade: check_dependencies
	jlpm up
	jlpm npm audit --recursive || true

## cleanup all build and metabuild artefacts (including the project-local nodeenv)
mrproper: clean uninstall
	rm -rf node_modules .yarn ui-tests/node_modules .nodeenv tmp logs .venv graphify-out coverage .pytest_cache || true

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

