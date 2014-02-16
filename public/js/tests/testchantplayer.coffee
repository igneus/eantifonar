# tests for chantplayer.coffee

test 'getting', (assert) ->
  player = ChantPlayerEngine.get_instance()
  assert.ok player instanceof ChantPlayerEngine

test_octave = (name, last_note, last_octave, note, EXPECTED_OCTAVE) ->
  test name, (assert) ->
    player = ChantPlayerEngine.get_instance()
    assert.equal player._octave(note, last_note, last_octave), EXPECTED_OCTAVE


test_octave 'first', 'c', 1, 'c', 1
test_octave 'second', 'c', 1, 'd', 1
test_octave 'third', 'c', 1, 'e', 1
test_octave 'fourth', 'c', 1, 'f', 1

# lilypond relative mode's principle of shorter step is applied
test_octave 'fifth? no - fourth downwards', 'c', 1, 'g', 0
test_octave 'sixth? no - third downwards', 'c', 1, 'a', 0
test_octave 'seventh? no - second downwards', 'c', 1, 'b', 0

test_octave 'second with octave shift', 'b', 1, 'c', 2
test_octave 'second with downwards octave shift', 'c', 1, 'b', 0
test_octave 'fourth with octave shift', 'a', 1, 'd', 2


test_parsenote = (name, token, expected) ->
  test name, (assert) ->
    player = ChantPlayerEngine.get_instance()
    assert.deepEqual player._parse_note(token), expected

test_parsenote 'wrong note', 'x', null
test_parsenote 'note only', 'c', ['c', null, 0]
test_parsenote 'note with duration', 'c4', ['c', 1, 0]
test_parsenote 'note, duration, shift up', "c'4", ['c', 1, 1]
test_parsenote 'note, duration, shift down', "c,4", ['c', 1, -1]
test_parsenote 'note, duration, shift up', "c'4", ['c', 1, 1]
test_parsenote 'note, shift up', "c'", ['c', null, 1]
test_parsenote 'note, shifts up', "c'''", ['c', null, 3]
test_parsenote 'note, shifts down', "c,,", ['c', null, -2]