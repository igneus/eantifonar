# eantifonar

(a small toy project; work in progress)

One of remarkable resources of the Czech Catholic internet is [ebreviar.cz](http://ebreviar.cz)
(see it's [source](https://github.com/breviar-sk/Liturgia-hodin-online)) - a "breviary on-line"
created and maintained by a Slovak programmer Juraj Vidéky. A lot of lay people as well as clergy and even [bishops](http://nazory.euro.e15.cz/rozhovory/frantisek-radkovsky-breviar-mam-v-mobilu-382531)
pray the hours from their (not necessarily smart-)phones using this website instead of carrying a volume of breviary with them.
*E-antifonar* is a facade of *e-breviar* adding chants to it's output.
It forwards all HTTP requests to ebreviar.cz and modifies returned html content before sending it to the client.

## Prerequisites

* lilypond (version compatible with the current In adiutorium music data)
* ImageMagick

## License

choose freely between GNU/GPL 3.0 or later and MIT
