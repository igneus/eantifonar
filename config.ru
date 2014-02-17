require 'sinatra'
require 'sass/plugin/rack'
require 'rack/coffee'

require './app'

# scss for stylesheets
Sass::Plugin.options[:style] = :compact
Sass::Plugin.options[:css_location] = 'public/css'
use Sass::Plugin::Rack

# coffeescript for javascript
use Rack::Coffee, root: 'public', urls: ['/js', '/vendor/js']

configure(:development) do
  enable :logging
  set :port, 4567
end

configure(:production) do
  log = File.new("log/error.log", "a+")
  $stderr.reopen(log)
end

run EAntifonarApp
