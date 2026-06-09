" Tests for the keystroke-counting helper exposed as
" vimfluency#_test_command_strokes. Each shifted character costs 2 (the
" shift + the base key); <…> chords cost 1 per modifier plus the base.
" The breakdown's stroke_count column reads through this function so
" the fairness lens for stroke_rate (last_rate / stroke_count) stays
" honest across single-key and multi-key commands.

" The examples the user explicitly walked through.
" Ex commands (anything starting with ':') get +1 for the trailing
" <Enter> that actually executes them, since the learner must press
" it for any : command to run.
call AssertEq(vimfluency#_test_command_strokes('q!'), 3,
  \ 'strokes: q! = q (1) + ! (shift+1 = 2) = 3')
call AssertEq(vimfluency#_test_command_strokes(':wq'), 5,
  \ 'strokes: :wq = : (2) + w (1) + q (1) + <Enter> (1) = 5')

" Single unshifted keys.
call AssertEq(vimfluency#_test_command_strokes('h'), 1, 'strokes: h = 1')
call AssertEq(vimfluency#_test_command_strokes('w'), 1, 'strokes: w = 1')
call AssertEq(vimfluency#_test_command_strokes('0'), 1, 'strokes: 0 = 1')

" Capitalized / symbol keys need shift, each = 2.
call AssertEq(vimfluency#_test_command_strokes('Z'), 2, 'strokes: Z = shift+z = 2')
call AssertEq(vimfluency#_test_command_strokes('$'), 2, 'strokes: $ = shift+4 = 2')
call AssertEq(vimfluency#_test_command_strokes('^'), 2, 'strokes: ^ = shift+6 = 2')

" Multi-character motions sum the per-char counts.
call AssertEq(vimfluency#_test_command_strokes('dd'), 2, 'strokes: dd = d + d = 2')
call AssertEq(vimfluency#_test_command_strokes('dw'), 2, 'strokes: dw = d + w = 2')
call AssertEq(vimfluency#_test_command_strokes('ge'), 2, 'strokes: ge = g + e = 2')
call AssertEq(vimfluency#_test_command_strokes('g_'), 3,
  \ 'strokes: g_ = g (1) + _ (shift+- = 2) = 3')
call AssertEq(vimfluency#_test_command_strokes('ZQ'), 4,
  \ 'strokes: ZQ = Z (shift+z) + Q (shift+q) = 4')
call AssertEq(vimfluency#_test_command_strokes(':q!'), 6,
  \ 'strokes: :q! = : (2) + q (1) + ! (2) + <Enter> (1) = 6')

" <…> chords: each modifier letter is 1 stroke, plus the base key.
call AssertEq(vimfluency#_test_command_strokes('<C-r>'), 2,
  \ 'strokes: <C-r> = ctrl (1) + r (1) = 2')
call AssertEq(vimfluency#_test_command_strokes('<C-S-x>'), 3,
  \ 'strokes: <C-S-x> = ctrl + shift + x = 3')
call AssertEq(vimfluency#_test_command_strokes('<Esc>'), 1,
  \ 'strokes: <Esc> = 1 (named key, no modifier)')
call AssertEq(vimfluency#_test_command_strokes('<CR>'), 1, 'strokes: <CR> = 1')
call AssertEq(vimfluency#_test_command_strokes('<C-Esc>'), 2,
  \ 'strokes: <C-Esc> = ctrl (1) + Esc (1) = 2')

" Mixed: chord followed by base keys.
call AssertEq(vimfluency#_test_command_strokes('i<Esc>'), 2,
  \ 'strokes: i<Esc> = i (1) + Esc (1) = 2')
