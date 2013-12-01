# eantifonar

One of remarkable resources of the Czech Catholic internet is [ebreviar.cz](http://ebreviar.cz) - a "breviary on-line"
created and maintained by a Slovak programmer Juraj Vidéky. A lot of lay people as well as clergy and even bishops
pray the hours from their (not necessarily smart-)phones using this website instead of carrying a volume of breviary with them.
*E-antifonar* is a facade of *e-breviar* adding chants to it's output.
It forwards all HTTP requests to ebreviar.cz and modifies returned html content before sendint it to the client.
