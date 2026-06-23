# Vim Fluency test runners. Mirrors .github/workflows/tests.yml so a
# green `make test` locally means a green CI. See tests/run.sh and
# tests/smoke_nvim.sh for the underlying harnesses.

.PHONY: test test-vim test-nvim smoke catalog help

# Full CI equivalent: vim suite + catalog freshness + nvim suite + smoke.
test: test-vim catalog test-nvim smoke
	@echo "all checks passed"

# Headless vim test suite (fast; vim -Es, no event loop).
test-vim:
	@echo "== vim suite =="
	./tests/run.sh

# Same suite under Neovim.
test-nvim:
	@echo "== nvim suite =="
	nvim --headless -Nu NONE -Es -S tests/run.vim

# Live-nvim RPC smoke test (real keystrokes, timers, autocmds, buffer
# open/close). Auto-skips with success if nvim isn't installed.
smoke:
	@echo "== nvim live smoke =="
	./tests/smoke_nvim.sh

# CATALOG.md is generated from drill meta(); CI fails on a stale copy.
catalog:
	@echo "== catalog freshness =="
	./scripts/gen-catalog.sh
	@git diff --exit-code CATALOG.md \
		|| { echo "CATALOG.md is stale — run scripts/gen-catalog.sh and commit."; exit 1; }

help:
	@echo "make test       run everything CI runs (vim + catalog + nvim + smoke)"
	@echo "make test-vim   headless vim suite only (fastest)"
	@echo "make test-nvim  headless suite under nvim"
	@echo "make smoke      live-nvim RPC smoke test"
	@echo "make catalog    regenerate CATALOG.md and check it's committed"
