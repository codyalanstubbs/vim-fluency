# Preview generation for Vim Fluency drills.
#
#   make verify              # render-free: assert :VfDemo plays every drill
#   make verify DRILL=<id>   # ...just one drill
#   make preview DRILL=<id>  # generate + render one drill's train GIF
#   make previews            # generate + render every drill's train GIF
#   make tapes               # generate tapes only (no render)
#   make clean               # remove generated tapes and renders
#
# Generated tapes (build/) and renders (renders/) are gitignored; commit
# only curated hero assets (e.g. demo.gif).

DRILL ?=

.PHONY: verify preview previews tapes clean

verify:
	./verify-demo.sh $(DRILL)

preview:
	@test -n "$(DRILL)" || { echo "usage: make preview DRILL=<id>"; exit 2; }
	./gen-previews.sh --render $(DRILL)

previews:
	./gen-previews.sh --render

tapes:
	./gen-previews.sh $(DRILL)

clean:
	rm -rf build renders
