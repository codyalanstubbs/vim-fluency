" Plugin loads, discovery resolves the expected pinpoints, each meta() is well-formed.

let s:registry = vimfluency#discover_pinpoints()

call Assert(len(s:registry) >= 3, 'smoke: registry has at least 3 pinpoints')
call Assert(has_key(s:registry, '1A.1'), 'smoke: 1A.1 registered')
call Assert(has_key(s:registry, '1A.2'), 'smoke: 1A.2 registered')
call Assert(has_key(s:registry, '1B.1'), 'smoke: 1B.1 registered')

for [s:id, s:info] in items(s:registry)
  call Assert(has_key(s:info, 'name') && !empty(s:info.name),
    \ 'smoke[' . s:id . ']: name present')
  call Assert(has_key(s:info, 'aim') && s:info.aim > 0,
    \ 'smoke[' . s:id . ']: positive aim')
  call Assert(has_key(s:info, 'allowed_keys'),
    \ 'smoke[' . s:id . ']: allowed_keys present')
endfor

" Public API surface
call Assert(exists('*vimfluency#start'),         'smoke: vimfluency#start exists')
call Assert(exists('*vimfluency#stop'),          'smoke: vimfluency#stop exists')
call Assert(exists('*vimfluency#learn'),         'smoke: vimfluency#learn exists')
call Assert(exists('*vimfluency#learn_stop'),    'smoke: vimfluency#learn_stop exists')
call Assert(exists('*vimfluency#close_summary'), 'smoke: vimfluency#close_summary exists')
call Assert(exists('*vimfluency#history'),       'smoke: vimfluency#history exists')
call Assert(exists('*vimfluency#list'),          'smoke: vimfluency#list exists')

" Commands
call Assert(exists(':Vf') == 2,        'smoke: :Vf defined')
call Assert(exists(':VfList') == 2,    'smoke: :VfList defined')
call Assert(exists(':VfQuit') == 2,    'smoke: :VfQuit defined')
call Assert(exists(':VfHistory') == 2, 'smoke: :VfHistory defined')
call Assert(exists(':VfLearn') == 2,   'smoke: :VfLearn defined')
