" Property tests over each pinpoint's meta(). Asserts the contract:
" id, name, aim, allowed_keys, prereqs are all present and well-typed.
" The :VfList navigator will rely on prereqs to compute eligibility, so
" a missing field is a runtime hazard, not a cosmetic issue.

let s:expected = [
  \ {'id': 'T0.1', 'prereqs': []},
  \ {'id': 'T0.2', 'prereqs': ['T0.1']},
  \ {'id': 'T0.3a', 'prereqs': []},
  \ {'id': 'T0.3b', 'prereqs': ['T0.3a']},
  \ {'id': 'T0.3c', 'prereqs': ['T0.3b']},
  \ {'id': 'T0.3d', 'prereqs': ['T0.3b']},
  \ {'id': 'T0.4', 'prereqs': []},
  \ {'id': 'T0.5', 'prereqs': []},
  \ {'id': '1A.1', 'prereqs': ['T0']},
  \ {'id': '1A.2', 'prereqs': ['T0']},
  \ {'id': '1B.1', 'prereqs': ['1A']},
  \ {'id': '1B.2', 'prereqs': ['1A']},
  \ {'id': '1C.1', 'prereqs': ['1A']},
  \ {'id': '1C.2', 'prereqs': ['1C.1']},
  \ {'id': '1C.3', 'prereqs': ['1C.1', '1C.2']},
  \ {'id': '1C.4', 'prereqs': ['1C.1', '1C.2']},
  \ {'id': '2.1',  'prereqs': ['T0']},
  \ {'id': '2.2',  'prereqs': ['T0']},
  \ {'id': '4.1',  'prereqs': ['2.1', '1B.1']},
  \ ]

let s:registry = vimfluency#discover_pinpoints()

for s:e in s:expected
  let s:prefix = 'meta[' . s:e.id . ']: '
  call Assert(has_key(s:registry, s:e.id),
    \ s:prefix . 'pinpoint discovered by runtime')
  if !has_key(s:registry, s:e.id) | continue | endif
  let s:m = s:registry[s:e.id]
  call Assert(has_key(s:m, 'id'),           s:prefix . 'has id')
  call Assert(has_key(s:m, 'name'),         s:prefix . 'has name')
  call Assert(has_key(s:m, 'aim'),          s:prefix . 'has aim')
  call Assert(has_key(s:m, 'allowed_keys'), s:prefix . 'has allowed_keys')
  call Assert(has_key(s:m, 'prereqs'),      s:prefix . 'has prereqs')
  if has_key(s:m, 'prereqs')
    call Assert(type(s:m.prereqs) == v:t_list,
      \ s:prefix . 'prereqs is a list')
    call AssertEq(s:m.prereqs, s:e.prereqs,
      \ s:prefix . 'prereqs match catalog')
  endif
endfor
