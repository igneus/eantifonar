// Generated by CoffeeScript 1.7.1
(function() {
  var test_octave;

  test('getting', function(assert) {
    var player;
    player = ChantPlayerEngine.get_instance();
    return assert.ok(player instanceof ChantPlayerEngine);
  });

  test_octave = function(name, last_note, last_octave, note, EXPECTED_OCTAVE) {
    test(name, function(assert) {
      var player;
      player = ChantPlayerEngine.get_instance();
      assert.equal(EXPECTED_OCTAVE, player._octave(note, last_note, last_octave));
      return null;
    });
    return null;
  };

  test_octave('first', 'a', 1, 'a', 1);

  test_octave('second', 'a', 1, 'b', 1);

  test_octave('second with octave shift', 'b', 1, 'c', 2);

}).call(this);
