" Plugin loads, discovery resolves the expected pinpoints, each meta() is well-formed.

let s:registry = toi#discover_pinpoints()

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
call Assert(exists('*toi#start'),         'smoke: toi#start exists')
call Assert(exists('*toi#stop'),          'smoke: toi#stop exists')
call Assert(exists('*toi#learn'),         'smoke: toi#learn exists')
call Assert(exists('*toi#learn_stop'),    'smoke: toi#learn_stop exists')
call Assert(exists('*toi#close_summary'), 'smoke: toi#close_summary exists')
call Assert(exists('*toi#history'),       'smoke: toi#history exists')
call Assert(exists('*toi#list'),          'smoke: toi#list exists')

" Commands
call Assert(exists(':Toi') == 2,        'smoke: :Toi defined')
call Assert(exists(':ToiList') == 2,    'smoke: :ToiList defined')
call Assert(exists(':ToiQuit') == 2,    'smoke: :ToiQuit defined')
call Assert(exists(':ToiHistory') == 2, 'smoke: :ToiHistory defined')
call Assert(exists(':ToiLearn') == 2,   'smoke: :ToiLearn defined')
