# Off-camera vim launch — Source'd after _setup.tape (and after any
# seed-history.sh step) by every preview/scene tape. preview/ sits at the
# plugin repo root, so the plugin is one dir up (..). `vim --clean` does
# NOT source plugin/*.vim from a prepended runtimepath, so launch with
# -u NONE + an explicit `runtime`.
Hide
Type "vim -u NONE -N --cmd 'set rtp^=..' -c 'runtime plugin/vimfluency.vim'"
Enter
Sleep 1500ms
Show
