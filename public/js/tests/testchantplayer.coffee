# tests for chantplayer.coffee

test 'getting', (assert) ->
  player = ChantPlayerEngine.get_instance()
  assert.ok player instanceof ChantPlayerEngine

test_octave = (name, last_note, last_octave, note, EXPECTED_OCTAVE) ->
  test name, (assert) ->
    player = ChantPlayerEngine.get_instance()
    assert.equal EXPECTED_OCTAVE, player._octave(note, last_note, last_octave)
    null
  null

test_octave 'first', 'a', 1, 'a', 1
test_octave 'second', 'a', 1, 'b', 1
test_octave 'second with octave shift', 'b', 1, 'c', 2
