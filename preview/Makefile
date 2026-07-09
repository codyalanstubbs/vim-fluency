# Preview generation for Vim Fluency — re-render a feature's GIF/MP4 when
# you change it, for docs and social. Two kinds of previews:
#
#   Per-drill previews (auto-played :VfDemo train + :VfLearnDemo learn,
#   generated from the registry — a learn preview for every drill with a
#   lesson):
#     make verify              # render-free: assert :VfDemo plays every drill
#     make verify DRILL=<id>   # ...just one drill
#     make preview DRILL=<id>  # generate + render one drill's train & learn GIF+MP4
#     make previews            # generate + render every drill's
#     make tapes               # generate the per-drill tapes only (no render)
#
#   Feature scenes (hand-authored views/flows in scenes/*.tape):
#     make scenes              # render every scene -> renders/scene-*.{gif,mp4}
#     make scene NAME=<name>   # ...just one (e.g. NAME=dashboard)
#     make scene-list          # list available scenes
#
#     make clean               # remove generated tapes and renders
#
#   Documentation assets (the curated set for the README + website):
#     make publish             # render every curated scene + push assets to
#                              # the website repo (vimfluency.com/assets/)
#     make publish NAME=<name> # ...just one scene (e.g. NAME=chart-struggle)
#     make publish SITE=<dir>  # ...to a different website-repo path
#
# Outputs (build/ tapes, renders/ GIFs+MP4s) are gitignored — regenerate
# them; commit only curated hero assets.

DRILL ?=
NAME ?=
SITE ?=

.PHONY: verify preview previews tapes scene scenes scene-list publish clean

verify:
	./verify-demo.sh $(DRILL)

preview:
	@test -n "$(DRILL)" || { echo "usage: make preview DRILL=<id>"; exit 2; }
	./gen-previews.sh --render $(DRILL)

previews:
	./gen-previews.sh --render

tapes:
	./gen-previews.sh $(DRILL)

scene:
	@test -n "$(NAME)" || { echo "usage: make scene NAME=<name> (see: make scene-list)"; exit 2; }
	./render-scene.sh $(NAME)

scenes:
	./render-scene.sh

scene-list:
	@ls scenes/*.tape 2>/dev/null | sed 's|scenes/||; s|\.tape$$||; s|^|  |' \
	  || echo "  (no scenes)"

publish:
	./publish.sh $(if $(NAME),--scene $(NAME)) $(if $(SITE),--site $(SITE))

clean:
	rm -rf build renders
