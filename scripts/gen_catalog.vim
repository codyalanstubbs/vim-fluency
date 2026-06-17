" Regenerate CATALOG.md from every drill's meta(). Machine-owned: the
" catalog is a static snapshot of data that lives in the drill files, so
" it never drifts and never references anything outside the public repo.
"
" Run via scripts/gen-catalog.sh. CI checks the committed copy is fresh.

set runtimepath+=.
runtime plugin/vimfluency.vim

" Family display order + labels. Kept in sync with s:FAMILY_NAMES in
" autoload/vimfluency.vim (script-local there, so mirrored here). Families
" not in this list fall through to the end under their raw slug.
let s:FAMILIES = [
  \ ['survival',           'Survival'],
  \ ['motion',             'Motions'],
  \ ['v',                  'Visual mode'],
  \ ['delete',             'Delete'],
  \ ['change',             'Change'],
  \ ['yank',               'Yank'],
  \ ['paste',              'Paste'],
  \ ['indent',             'Indent'],
  \ ['text-object-recall', 'Text objects'],
  \ ]

function! s:cell(s) abort
  " Escape pipes so a stray '|' in a name can't break the table.
  return substitute(a:s, '|', '\\|', 'g')
endfunction

function! s:code(s) abort
  " Markdown inline code. A value containing a backtick (e.g. the `i`` motion)
  " needs double-backtick fencing with padding spaces.
  let v = s:cell(a:s)
  return v =~ '`' ? '`` ' . v . ' ``' : '`' . v . '`'
endfunction

let s:registry = vimfluency#discover_drills()
let s:total = len(keys(s:registry))

" Bucket drills by family.
let s:by_family = {}
for s:id in keys(s:registry)
  let s:fam = get(s:registry[s:id], 'family', 'zzz')
  let s:by_family[s:fam] = get(s:by_family, s:fam, []) + [s:id]
endfor

" Emit families in curated order first, then any unknown family by slug.
let s:order = map(copy(s:FAMILIES), 'v:val[0]')
let s:labels = {}
for [s:f, s:label] in s:FAMILIES | let s:labels[s:f] = s:label | endfor
for s:f in sort(keys(s:by_family))
  if index(s:order, s:f) < 0 | call add(s:order, s:f) | let s:labels[s:f] = s:f | endif
endfor

let s:out = []
call add(s:out, '# Vim Drill Catalog')
call add(s:out, '')
call add(s:out, '> **Generated file — do not edit by hand.** Produced from each')
call add(s:out, '> drill''s `meta()` by `scripts/gen-catalog.sh`. Run that script after')
call add(s:out, '> adding or changing a drill; CI checks this copy is fresh.')
call add(s:out, '')
call add(s:out, 'Drills currently shipped, grouped by family. The live,')
call add(s:out, 'always-current view is `:VfList` (with per-drill rate/aim status);')
call add(s:out, 'this file is the static snapshot for browsing on GitHub.')
call add(s:out, '')
call add(s:out, '## Columns')
call add(s:out, '')
call add(s:out, '- **id (slug)** — what you type into `:VfTrain <id>` / `:VfLearn <id>` / `:VfChart <id>`.')
call add(s:out, '- **name** — human-readable label for the trained behavior.')
call add(s:out, '- **keys** — the drilled keystrokes (slash-separated).')
call add(s:out, '- **kind** — training kind (`motion` is the default; others: `editing`, `mode`, `mode_switch`, `command`, `recall`, `visual_motion`). See `:help vf-kinds`.')
call add(s:out, '- **aim** — starting-guess fluency rate (correct/min); revised from community data, not intuition.')
call add(s:out, '- **prereqs** — drill slugs suggested as fallbacks when a rate plateaus. **Diagnostic, not gating** — any drill is trainable at any time.')
call add(s:out, '')

for s:f in s:order
  if !has_key(s:by_family, s:f) | continue | endif
  call add(s:out, '## ' . get(s:labels, s:f, s:f))
  call add(s:out, '')
  call add(s:out, '| id (slug) | name | keys | kind | aim | prereqs |')
  call add(s:out, '|---|---|---|---|---|---|')
  for s:id in sort(s:by_family[s:f])
    let s:m = s:registry[s:id]
    let s:kind = get(s:m, 'kind', 'motion')
    let s:prereqs = get(s:m, 'prereqs', [])
    let s:pre = empty(s:prereqs) ? '—' : join(map(copy(s:prereqs), 's:code(v:val)'), ', ')
    call add(s:out, printf('| %s | %s | %s | `%s` | %d | %s |',
      \ s:code(s:id),
      \ s:cell(get(s:m, 'name', '')),
      \ s:code(get(s:m, 'keys', '')),
      \ s:kind,
      \ get(s:m, 'aim', 0),
      \ s:pre))
  endfor
  call add(s:out, '')
endfor

let s:nfam = len(filter(copy(s:order), 'has_key(s:by_family, v:val)'))
call add(s:out, printf('_%d drills across %d families. Regenerate with `scripts/gen-catalog.sh`._',
  \ s:total, s:nfam))

call writefile(s:out, 'CATALOG.md')
call writefile(['wrote CATALOG.md (' . s:total . ' drills)'], '/dev/stdout')
qa!
