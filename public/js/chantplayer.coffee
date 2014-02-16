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
    console.log 'initializing engine'
    this._load()

  play: (music) ->
    console.log 'simulating to play '+music

    if not MIDI?
      console.log 'wait'
      playclbk = => this.play(music)
      setTimeout(playclbk, 1000)
      return

    MIDI.loadPlugin({
      soundfontUrl: ChantPlayerEngine.sound_dir,
      instrument: "acoustic_grand_piano",
      callback: =>
        console.log 'music'
        delay = 1 # play one note every quarter second
        # play the note
        MIDI.setVolume(0, 127)
        mus = this._lily2midi(music)
        console.log mus
        this._play_sequence(mus)
    })

  # translates _simple_ lilypond source
  # to midi notes
  _lily2midi: (src) ->
    notes_dict =
      c: 60
      d: 62
      e: 64
      f: 65
      g: 67
      a: 68
      bes: 69
      b: 70

    midi = []
    chunks = src.split(/\s/)
    for c in chunks
      m = c.match(/^([cdefgab])([1234])*(.*)*$/)
      if not m?
        console.log 'dropping '+c
        continue
      note = m[1] # for now, drop duration and everything else
      if not note of notes_dict
        console.log 'unknown note ' + note
        continue
      midi.push notes_dict[note]
    return midi

  # fake implementation - no duration concerns
  # notes: array of ints
  _play_sequence: (notes, unit_duration=0.3) ->
    i = 0
    play = => # recursive loop to play pattern
      setTimeout( (=>
        this._play_single(notes[i], unit_duration);
        i++;
        if i < notes.length
          play()
        ), unit_duration * 1000)

    play()

  # note: int
  # duration: int/float - duration in seconds
  _play_single: (note, duration=1) ->
    channel = 0
    velocity = 200
    delay = 0
    MIDI.noteOn(channel, note, velocity, delay)
    setTimeout((-> MIDI.noteOff(channel, note, delay+0.25)), duration * 1000);

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
    this._load_js(ChantPlayerEngine.libs_dir + l) for l in libs

  # load single js library
  _load_js: (src) ->
    s = document.createElement('script')
    s.type = 'text/javascript'
    s.src = src
    x = document.getElementsByTagName('script')[0]
    x.parentNode.insertBefore(s, x)


# function to bind a chantplayer to an event of an element
window.addChantPlayer = (elem, event, music) ->
  elem.on event, ->
    p = ChantPlayerEngine.get_instance()
    p.play(music)
