" Tiny assertion library. Failures are appended to g:toi_test_failures and
" surfaced by run.vim. No exceptions thrown — tests continue past failures
" so a single broken pinpoint doesn't hide bugs in others.

function! Assert(cond, msg) abort
  if !a:cond
    call add(g:toi_test_failures, a:msg)
  endif
endfunction

function! AssertEq(actual, expected, msg) abort
  if a:actual !=# a:expected
    call add(g:toi_test_failures,
      \ a:msg . '  (expected ' . string(a:expected)
      \ . ', got ' . string(a:actual) . ')')
  endif
endfunction

function! AssertIn(value, list, msg) abort
  if index(a:list, a:value) < 0
    call add(g:toi_test_failures,
      \ a:msg . '  (expected one of ' . string(a:list)
      \ . ', got ' . string(a:value) . ')')
  endif
endfunction
