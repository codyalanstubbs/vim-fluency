" Test orchestrator. Sources assert.vim then every test_*.vim under tests/.
" Reports PASS/FAIL via writefile to /dev/stdout. cquit on failure.

set runtimepath+=.
runtime plugin/toi.vim

let s:tests_dir = expand('<sfile>:p:h')

execute 'source ' . s:tests_dir . '/assert.vim'

let g:toi_test_failures = []
let g:toi_test_files = 0

for s:f in sort(globpath(s:tests_dir, 'test_*.vim', 0, 1))
  let g:toi_test_files += 1
  execute 'source ' . s:f
endfor

if empty(g:toi_test_failures)
  call writefile(['PASS  ' . g:toi_test_files . ' file(s)'], '/dev/stdout')
  qa
else
  call writefile(['FAIL  ' . len(g:toi_test_failures) . ' assertion(s)'], '/dev/stdout')
  for s:msg in g:toi_test_failures
    call writefile(['  ' . s:msg], '/dev/stdout')
  endfor
  cquit
endif
