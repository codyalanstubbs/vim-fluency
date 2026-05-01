" Test orchestrator. Sources assert.vim then every test_*.vim under tests/.
" Reports PASS/FAIL via writefile to /dev/stdout. cquit on failure.

set runtimepath+=.
runtime plugin/vimfluency.vim

let s:tests_dir = expand('<sfile>:p:h')

execute 'source ' . s:tests_dir . '/assert.vim'

let g:vf_test_failures = []
let g:vf_test_files = 0

for s:f in sort(globpath(s:tests_dir, 'test_*.vim', 0, 1))
  let g:vf_test_files += 1
  execute 'source ' . s:f
endfor

if empty(g:vf_test_failures)
  call writefile(['PASS  ' . g:vf_test_files . ' file(s)'], '/dev/stdout')
  qa
else
  call writefile(['FAIL  ' . len(g:vf_test_failures) . ' assertion(s)'], '/dev/stdout')
  for s:msg in g:vf_test_failures
    call writefile(['  ' . s:msg], '/dev/stdout')
  endfor
  cquit
endif
