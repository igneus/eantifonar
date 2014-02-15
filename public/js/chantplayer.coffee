# chantplayer

# a simple music player based on MIDI.js

# singleton.
# Responsible for MIDI.js loading and music synthesis
class ChantPlayerEngine

  @_instance = false

  @get_instance: ->
    if @_instance is false
      @_instance = new ChantPlayerEngine
    return @_instance

  # never call the constructor directly,
  # always use ChantPlayerEngine.get_instance
  constructor: ->
    console.log 'initializing engine'

  play: (music) ->
    console.log 'simulating to play '+music

# created every time a chant is to be played
class ChantPlayer

  # @src - a string containing _simple_ LilyPond music
  constructor: (@src) ->
    @engine = ChantPlayerEngine.get_instance()

  play: ->
    @engine.play @src


# function to bind a chantplayer to an event of an element
window.addChantPlayer = (elem, event, music) ->
  elem.on event, ->
    p = new ChantPlayer music
    p.play()
