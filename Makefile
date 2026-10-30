# Makefile for Jupyterlab extensions version 1.46
# changelog:
#   1.46 - increment_version also writes the new version into package-lock.json, in
#          its top-level `version` and in `packages[""].version`, when the project
#          has that file, and publish stages it in the metadata commit. 1.41 stopped
#          writing package-lock.json but the projects kept the file, so the version
#          recorded there stopped moving. Measured on 2026-10-14: 8 of 48 extensions
#          with a package-lock.json recorded an older version there than in
#          package.json, the oldest 1.2.31 against 1.2.73. The two values are replaced
#          in the text, because 6 of the 48 lockfiles are indented with 4 spaces and a
#          JSON rewrite would re-indent them. Requested on 2026-10-14.
#   1.45 - `install` installs every optional-dependencies group of pyproject.toml
#          with the wheel, so one `make install` leaves the runtime and the optional
#          dependencies in place. Until now it installed the wheel alone, and the
#          `dev` and `test` groups stayed as the image had them. Measured on
#          2026-10-03: a rebuilt container had lost pytest, `make install` reported
#          success twice, and `make publish` then stopped in `test` with "No module
#          named '_pytest'". The optional groups are installed in a second pip run
#          without --force-reinstall, so a build whose groups are already in place
#          reinstalls none of them. Requested on 2026-10-03.
#   1.44 - check_dependencies reports pytest missing when the package has a tests/
#          directory, and install_dependencies then installs the `test` extras that
#          pyproject.toml lists. `test` has run pytest since 1.36 and `publish` runs
#          `test` since 1.41, yet no target installed it: a dev env worked only where
#          the image happened to ship pytest. Measured on 2026-09-30: a Python 3.14
#          image answered "No module named pytest" after `make install` had reported
#          success, so `test`, and with it `publish`, had no pytest to run.
#          Frontend-only extensions (no tests/ directory) are unaffected.
#   1.43 - the auth gate in `test` loads the source tree being released, not the wheel
#          the last `make install` left in site-packages: `python script.py` puts only
#          the script's own directory on sys.path, and `publish` runs `test` before
#          `install`, so the gate checked the previous build.
#   1.42 - increment_version moves from `publish` onto `install`, so every
#          `make install` raises the patch version again, as it did through 1.40.
#          `publish` reaches it through `install` and still raises it exactly once;
#          `make build` alone leaves the version as it is. Requested on 2026-09-25.
#   1.41 - increment_version moves off `build` and onto `publish`; `publish` gains
#          `test`; the metadata commit and push happen BEFORE either registry is
#          written to; `npm install` and package-lock.json are dropped.
#          Measured on 2026-09-20 against jupyterlab_advanced_paste_content_extension.
#          With increment_version on the build chain, a routine `make install`
#          rewrote a deliberately pinned 1.0.0, and a build that FAILED in tsc still
#          consumed the bump - 1.0.0 became 1.0.2 for one artefact that never
#          existed. No published version can be rebuilt, because building it again
#          produces the next one. The release path also never reached `test`: the
#          string `test` appeared nowhere in publish's prerequisite chain, so jest,
#          pytest and check_auth.py - the gate that exists to catch a handler
#          missing @tornado.web.authenticated - could not block a release.
#          `git push` ran AFTER both uploads and aborts outright on a repository
#          with no remote, leaving npm and PyPI written and the operator reading a
#          red target; and an npm success followed by a twine failure forks the two
#          registries permanently, because npm never re-serves a consumed version.
#          Committing first costs nothing when a later step fails.
#          `$(NPM) install` ran immediately before `jlpm install`, writing a
#          package-lock.json that nothing reads - CI installs with jlpm, and npm
#          honours `overrides` rather than the `resolutions` these projects pin
#          with. `git add` then named that file, and on a project which never
#          produces it the add fails on an unmatched pathspec, so the commit and
#          push never run at all.
#   1.40 - publish stages yarn.lock in the post-publish commit. It staged only
#          package.json and package-lock.json, and `git add package.json` takes every
#          change in that file, so a dependency added since the last commit went out
#          without its yarn.lock entry. CI installs with an immutable lockfile and
#          failed both workflows on that commit with YN0028 "The lockfile would have
#          been modified by this install" (measured on 2026-09-14, release 1.0.12 of
#          jupyterlab_advanced_markdown_viewer_extension). The staged yarn.lock is the
#          one `jlpm install` wrote for the build that was published.
#   1.39 - upgrade no longer runs `npm audit fix --force`; it reports with
#          `jlpm npm audit --recursive` instead. Measured on six extensions on
#          2026-09-08: the forced fix rewrote every @jupyterlab/* range to a 0.x
#          release predating JupyterLab 4 (application ^0.18.6, testutils ^0.2.4,
#          rendermime ^0.18.4) while printing that it would install 4.6.3, and
#          because npm updates a yarn.lock it finds, it rewrote the Yarn Berry
#          lockfile in the Yarn 1 format. Every project had to restore package.json
#          and both lockfiles from git by hand. Any `npm audit fix`, forced or not,
#          rewrites yarn.lock the same way, so the target reports advisories and
#          changes nothing; `jlpm up` remains the one upgrade step. The report exits
#          1 whenever an advisory stands, hence the `|| true`.
#   1.38 - keep `python -m build` as the build command, approve blocked npm install
#          scripts, and audit-fix on upgrade.
#          A local edit in one project had swapped `python -m build` for
#          `jupyter-builder build`; canonical 1.37 never carried that. Measured, the
#          swap breaks the build twice over. jupyter-builder emits
#          no sdist and no wheel, so nothing populated dist/ - and `install`
#          (pip install dist/*.whl) plus `publish` (twine upload dist/*) both read
#          dist/, so publish pushed the npm tarball and then died at twine with the
#          npm version already consumed and unrepublishable. It also exits 1 outright
#          when run after `clean`: "Cannot find module lib/index.js", because it never
#          runs tsc. `python -m build` needs no help - its hatch-jupyter-builder hook
#          runs the pyproject `build_cmd` (build:prod = tsc + labextension) during the
#          sdist stage, then builds the wheel from that sdist. Verified from a tree
#          with no lib/, no labextension/ and no dist/: both artefacts, exit 0.
#          publish now asserts dist/ holds a wheel and an sdist BEFORE the npm push,
#          so a broken build cannot desynchronise the two registries.
#          npm >= 11.6 blocks dependency install scripts until approved and records
#          the approval in package.json under "allowScripts", so a transitive
#          package needing a lifecycle script installs unbuilt and fails at runtime.
#          install_dependencies now approves every package in ALLOW_SCRIPTS_PKGS.
#          upgrade runs `npm audit fix --force` after `jlpm up`. WARNING: --force
#          accepts breaking changes, including downgrades - on this project it
#          proposes @jupyterlab/testutils@0.2.4 in place of ^4.6.3. Review the diff
#          to package.json and the lockfiles after every upgrade. The trailing
#          `|| true` is required: npm audit fix exits 1 whenever any advisory
#          remains unfixed, which is the normal outcome, and would abort the target.
#          check_dependencies / install_dependencies now also gate the `build` module
#          and `jlpm` (supplied by the jupyter_builder distribution), the two commands
#          every build reaches for, so a fresh clone self-heals instead of dying
#          mid-build on a missing tool.
#   1.37 - pin the global install prefix to the nodeenv when installing yarn + rimraf.
#          `npm install -g` honours a user-level `prefix=` in ~/.npmrc even when run
#          from the nodeenv's own npm, so on any machine that sets one the binaries
#          landed in that prefix instead of $(NODEENV)/bin. check_dependencies tests
#          for $(NODEENV)/bin/yarn, which then never became true, so every make
#          invocation re-ran install_dependencies and reinstalled yarn - it never
#          reported "All dependencies are installed". Passing --prefix explicitly
#          overrides the config for that one command and leaves ~/.npmrc untouched.
#   1.36 - `test` runs the Python suite too, not just jlpm. It ran `jlpm test` alone,
#          so on any extension with a server side a Python regression passed local
#          verification and only failed in CI. pytest now runs whenever the package
#          has a tests/ directory, and is skipped with a message when it does not,
#          so frontend-only extensions are unaffected. No --cov: coverage is a CI
#          concern, and requiring pytest-cov would make `make test` fail on an
#          otherwise working dev env. Also corrects the author address to the
#          +github alias used everywhere else.
#   1.35 - resolve node and npm exclusively from the project-local nodeenv via $(NODE)
#          and $(NPM) instead of bare names, and read VERSION lazily at recipe time
#          rather than at parse time. VERSION := $(shell command -v node ...) was
#          evaluated before any target ran, so on a fresh clone (no .nodeenv yet) it
#          fell back to 0.0.0, increment_version's sed matched nothing, and the build
#          published the already-published version while printing a successful bump.
#          It only appeared to work where an ambient node happened to be on PATH.
#          increment_version now depends on check_dependencies and fails loudly when
#          the version cannot be read or does not actually change.
#   1.34 - build formats the lockfiles with `jlpm prettier` (the project's pinned
#          toolchain) instead of `npx prettier`, which fails with "prettier: Permission
#          denied" against a yarn-berry node_modules where the .cjs lacks the exec bit
#   1.33 - check_dependencies now also treats a missing/empty node_modules as a missing
#          dependency, and install_dependencies runs `jlpm install` to populate it, so
#          `make install`/`test` self-heal a fresh env without needing a full build first
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
# author: Stellars Henson <konrad.jelen+github@gmail.com>
# License: MIT Open Source License

.PHONY: build install clean uninstall publish dependencies mrproper increment_version install_dependencies check_dependencies upgrade help test
.DEFAULT_GOAL := help

# Project-local node environment - keeps node/npm/yarn pinned per project and out of
# the python prefix. Created by `install_dependencies` and torn down by `mrproper`.
NODEENV := $(CURDIR)/.nodeenv
NODE := $(NODEENV)/bin/node
NPM := $(NODEENV)/bin/npm
export PATH := $(NODEENV)/bin:$(PATH)

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
	NEW_VERSION="$${CURRENT_VERSION%.*}.$$(( $${CURRENT_VERSION##*.} + 1 ))"; \
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

