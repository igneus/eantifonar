# tests for chantplayer.coffee

test 'getting', (assert) ->
  player = ChantPlayerEngine.get_instance()
  assert.ok player instanceof ChantPlayerEngine

test_octave = (name, last_note, last_octave, note, EXPECTED_OCTAVE) ->
  test name, (assert) ->
    player = ChantPlayerEngine.get_instance()
    assert.equal player._octave(note, last_note, last_octave), EXPECTED_OCTAVE

# lilypond relative mode's principle of shorter step

test_octave 'first', 'c', 1, 'c', 1
test_octave 'second', 'c', 1, 'd', 1
test_octave 'third', 'c', 1, 'e', 1
test_octave 'fourth', 'c', 1, 'f', 1

test_octave 'fifth? no - fourth downwards', 'c', 1, 'g', 0
test_octave 'sixth? no - third downwards', 'c', 1, 'a', 0
test_octave 'seventh? no - second downwards', 'c', 1, 'b', 0

test_octave 'second with octave shift', 'b', 1, 'c', 2
test_octave 'second with downwards octave shift', 'c', 1, 'b', 0
test_octave 'fourth with octave shift', 'a', 1, 'd', 2
