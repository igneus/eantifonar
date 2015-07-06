# eantifonar

(a small toy project; work in progress)

One of remarkable resources of the Czech Catholic internet is [ebreviar.cz](http://ebreviar.cz)
(see it's [source](https://github.com/breviar-sk/Liturgia-hodin-online)) - a "breviary on-line"
created and maintained by a Slovak programmer Juraj Vidéky. A lot of lay people as well as clergy and even [bishops](http://nazory.euro.e15.cz/rozhovory/frantisek-radkovsky-breviar-mam-v-mobilu-382531)
pray the hours from their (not necessarily smart-)phones using this website instead of carrying a volume of breviary with them.
*E-antifonar* is a proxy of *e-breviar* adding chants to it's output.
It forwards some HTTP requests to ebreviar.cz and modifies returned html content before sending it to the client.

See eantifonar in action at [http://ean.inadiutorium.cz](http://ean.inadiutorium.cz)

## Prerequisites

* ruby 2.0.x (used for development; earlier versions not tested)
* bundler or otherwise installed gems according to the provided Gemfile
* SQLite 3
* lilypond (version compatible with the current In adiutorium music data)
* ImageMagick

## Install

$ bundle install

## Run

1. Clone the [In adiutorium](https://github.com/igneus/In-adiutorium) project e.g. to ~/tmp/In-adiutorium

2. Prepare database of scores: (Two hours or more are a normal amount of time needed for this operation.)

    $ bundle exec ruby bin/indexer.rb -Rt ~/tmp/In-adiutorium

3. On your development machine start the web application using:

    $ bundle exec rackup

Or, for automatic code reloading:

    $ bundle exec shotgun

For deployment on a production server see your server's documentation concerning Rack applications.

Or

## License

choose freely between GNU/GPL 3.0 or later and MIT
