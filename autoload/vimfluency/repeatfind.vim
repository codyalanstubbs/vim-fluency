" Shared cheat-defense for the repeat-find drill family (; / ,).
"
" A `;` repeat item is supposed to force a two-motion sequence
" (f{c}; / t{c}; / …). But if some single f/F/t/T motion happens to
" land directly on the target — because the char it keys off is the
" first occurrence in that direction — the learner can reach the
" target in ONE motion and never press ;. With random noise around
" the two search-char occurrences that shortcut exists in ~80% of
" `;` items.
"
" This module detects those single-motion routes and repairs them by
" dropping a duplicate of the offending char into the gap between the
" waypoint and the target, so the motion stops at the closer copy.
" (The `,` scenario is intrinsically one-motion-reachable — `f{c},`
" lands exactly where `F{c}` does — so it is left alone; only `;`
" items are repaired.)
"
" Lives outside autoload/vimfluency/drills/ so drill discovery doesn't
" treat it as a drill. The simulation is pure string-scan (no buffer),
" which makes it safe to call from generate() and immune to the
" cpoptions ';' quirk (that only affects ; / , repeats, not the base
" f/F/t/T motions).

" Landing column (1-indexed) of a single find/till motion from cursor
" col `sc` over `line`, or 0 if the motion wouldn't move the cursor.
"   f{c} → on the next c        t{c} → one cell before the next c
"   F{c} → on the previous c    T{c} → one cell after the previous c
function! s:land(line, sc, motion, ch) abort
  let n = len(a:line)
  if a:motion ==# 'f' || a:motion ==# 't'
    let k = a:sc + 1
    while k <= n
      if a:line[k-1] ==# a:ch
        let dest = a:motion ==# 'f' ? k : k - 1
        return dest > a:sc ? dest : 0
      endif
      let k += 1
    endwhile
  else
    let k = a:sc - 1
    while k >= 1
      if a:line[k-1] ==# a:ch
        let dest = a:motion ==# 'F' ? k : k + 1
        return dest < a:sc ? dest : 0
      endif
      let k -= 1
    endwhile
  endif
  return 0
endfunction

" Chars c for which some single f/F/t/T motion from `sc` lands exactly
" on `tc` — i.e. the one-motion shortcuts that bypass the ; / , repeat.
function! vimfluency#repeatfind#cheat_chars(line, sc, tc) abort
  let chars = {}
  for i in range(len(a:line)) | let chars[a:line[i]] = 1 | endfor
  let hits = {}
  for ch in keys(chars)
    if ch ==# ' ' | continue | endif
    for mo in ['f', 't', 'F', 'T']
      if s:land(a:line, a:sc, mo, ch) == a:tc
        let hits[ch] = 1
        break
      endif
    endfor
  endfor
  return keys(hits)
endfunction

" Repair a `;`-scenario line so no single motion reaches the target:
" for each shortcut char, write a duplicate into a noise cell strictly
" between the waypoint and the target (skipping the search-char cells),
" so the motion stops at the closer copy. Bounded loop — one pass
" clears it in practice. Returns the repaired line; if it can't be
" cleared (no free gap cell), returns the best effort and the caller's
" test will catch any residue.
function! vimfluency#repeatfind#decheat(line, sc, tc, wp, search) abort
  let line = a:line
  let lo = min([a:wp, a:tc]) + 1
  let hi = max([a:wp, a:tc]) - 1
  let used = {}
  let attempts = 0
  while attempts < 12
    let attempts += 1
    let cheats = vimfluency#repeatfind#cheat_chars(line, a:sc, a:tc)
    if empty(cheats) | break | endif
    let c = cheats[0]
    let placed = 0
    for j in range(lo, hi)
      if has_key(used, j) | continue | endif
      if line[j-1] ==# a:search || line[j-1] ==# c | continue | endif
      let line = strpart(line, 0, j-1) . c . strpart(line, j)
      let used[j] = 1
      let placed = 1
      break
    endfor
    if !placed | break | endif
  endwhile
  return line
endfunction

" The expert keystroke plan for a repeat-find/till item, as a list of two
" motion atoms for the demo player (:VfDemo) to perform as two visible
" jumps: prime the search with f/t/F/T + the char (landing on the
" waypoint), then repeat it with the item's ; or , (landing on the
" target). The prime direction is taken from the geometry — forward when
" the waypoint is right of the cursor, backward otherwise — so the same
" helper serves the forward, backward, and mixed drills. `is_till` picks
" t/T over f/F; `ch` is the search character.
function! vimfluency#repeatfind#solve(item, is_till, ch) abort
  let fwd = a:item.waypoints[0][1] > a:item.start[1]
  let prime = a:is_till ? (fwd ? 't' : 'T') : (fwd ? 'f' : 'F')
  return [prime . a:ch, a:item.expected_motion]
endfunction
