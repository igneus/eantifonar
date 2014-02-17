# chantplayer

# a simple music player based on MIDI.js

# singleton.
# Responsible for MIDI.js loading and music synthesis
class ChantPlayerEngine

  @_instance = undefined

  @libs_dir = '/vendor/js/midijs/'
  @sound_dir = '/vendor/soundfont/'

  # call get_instance to obtain reference
  # to the singleton instance of this class
  @get_instance: ->
    if not @_instance?
      @_instance = new ChantPlayerEngine
    return @_instance

  # never call the constructor directly,
  # always use ChantPlayerEngine.get_instance
  constructor: ->
    @_load()

    @notes_dict =
      c: 0
      d: 2
      e: 4
      f: 5
      g: 7
      a: 9
      bes: 10
      b: 11
    @rests_dict =
      '\\barMin': 0.5
      '\\barMaior': 1
      '\\barMax': 2
      '\\barFinalis': 3

  # music: string, a block of music in lilypond \relative format
  play: (music) ->
    unless MIDI?
      console.log "wait\'n\'retry"
      setTimeout((=> @play music), 1000)
      return

    MIDI.loadPlugin({
      soundfontUrl: ChantPlayerEngine.sound_dir,
      instrument: "acoustic_grand_piano",
      callback: =>
        delay = 1 # play one note every quarter second
        # play the note
        MIDI.setVolume(0, 127)
        mus = @_lily2midi(music)
        @_play_sequence(mus)
    })

  # translates _simple_ lilypond source
  # to midi notes
  _lily2midi: (src) ->
    midi = []
    skip_next = false
    chunks = src.split(/\s+/)
    last = null # last note and octave
    last_chunk = null # last raw token

    base_c = 60
    octave_size = 12
    octave = 0 # c'

    duration = 1
    for c in chunks
      if last_chunk == '\\relative'
        if c[1..] == "'"
          octave = 0
        else if c[1..] == "''"
          octave = 1

        last =
          note: c[0]
          octave: octave

      else if skip_next
        skip_next = false

      else if c == '\\relative' or c == '\\key' or c == '\\neviditelna' # note-like token with special meaning follows
        skip_next = true

      else if c of @rests_dict
        midi.push([ null, @rests_dict[c] ])

      else
        parsed = @_parse_note(c)
        unless parsed?
          console.log 'failed to parse ' + c
        else
          [note, dur, octave_shift] = parsed
          duration = dur if dur?
          octave = @_octave(note, last.note, last.octave)
          octave += octave_shift
          midi_note = base_c + octave * octave_size + @notes_dict[note]
          midi.push [ midi_note, duration ]

          last =
            note: note
            octave: octave

      last_chunk = c
    return midi

  # computes octave shift
  _octave: (note, last_note, last_octave) ->
    octave = last_octave
    step = @notes_dict[note] - @notes_dict[last_note]
    if Math.abs(step) > 6
      octave -= Math.sign(step)
    return octave

  # parses note token
  # return null on error
  # otherwise three values: note (string), duration (integer), octave shift (integer)
  _parse_note: (token) ->
    # the only known durations are 4 and 4.
    # the only known notes are diatonic notes and bes
    # anything but pitch, octave shift and duration is ignored
    shift = 0
    duration = null

    m = token.match(/^([cdefga]|bes|b)([',]*)*((4)*(\.*)*).*$/)
    if not m?
      return null

    note = m[1]
    unless note of @notes_dict
      return null

    if m[2]
      shift = m[2].length
      if m[2][0] == ','
        shift *= -1

    mdur = m[3]
    if mdur == '4'
      duration = 1
    else if mdur == '4.'
      duration = 2

    return [note, duration, shift]

  # fake implementation - no duration concerns
  # notes: array of ints
  _play_sequence: (notes, unit_duration=0.3) ->
    if notes.length == 0
      console.log 'no notes.'
      return

    i = 0
    last_duration = 0
    play = => # recursive loop to play a sequence
      duration = notes[i][1] * unit_duration # in seconds
      setTimeout( (=>
          @_play_single(notes[i][0], duration);
          i++;
          if i < notes.length
            play()
        ), last_duration * 1000)
      last_duration = duration

    play()

  # note: int
  # duration: int/float - duration in seconds
  _play_single: (note, duration=1) ->
    unless note?
      return # note=null: rest

    channel = 0
    velocity = 200
    delay = 0
    MIDI.noteOn(channel, note, velocity, delay) if note?
    setTimeout((-> MIDI.noteOff(channel, note, delay+0.25) if note?), duration * 1000);

  # load necessary libraries
  _load: ->
    libs = [
      # MIDI.js library
      'MIDI/AudioDetect.js',
      'MIDI/LoadPlugin.js',
      'MIDI/Plugin.js',
      'MIDI/Player.js',
      'Window/DOMLoader.XMLHttp.js',
      'Base64.js',
      'base64binary.js'
    ]
    @_load_js(ChantPlayerEngine.libs_dir + l) for l in libs

  # load single js library
  _load_js: (src) ->
    s = document.createElement('script')
    s.type = 'text/javascript'
    s.src = src
    x = document.getElementsByTagName('script')[0]
    x.parentNode.insertBefore(s, x)

# make accessible for unit testing (non-public API)
window.ChantPlayerEngine = ChantPlayerEngine

class ChantPlayerControl

  # parent - jquery object to append the control to
  # music - lilypond source
  constructor: (@parent, @music) ->
    @parent.append '<div class="chantplayer"><div class="btn-play">Přehrát</div></div>'
    wrapper = $('.chantplayer', @parent)
    btn = $('.btn-play', wrapper)
    @ui =
      wrapper: wrapper
      btn: btn
    @ui.btn.on 'click', =>
      @play()

  play: ->
    ChantPlayerEngine.get_instance().play @music

# ensure presence of features not yet generally supported we rely on
do -> Math.sign ?= (num) ->
  if num == 0
    return 0
  return Math.round(num / Math.abs(num))

do -> console.log ?= (stuff) ->

#== public API

# function to bind a chantplayer to an event of an element
window.addChantPlayer = (elem, event, music) ->
  new ChantPlayerControl elem, music
