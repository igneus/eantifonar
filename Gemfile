source 'https://rubygems.org'

gem 'sinatra'
gem 'haml'
gem 'sass'
gem 'rack-coffee'

gem 'typhoeus' # http requests
gem 'nokogiri'
gem 'mime-types'
gem 'log4r'

gem 'datamapper'
gem 'dm-sqlite-adapter'

# only for the indexer, not for the web app
group :indexer do
  gem 'rugged' # git - access repo data
end

group :test do
  gem 'rspec'
  gem 'rack-test'
end

group :development do
  gem 'capistrano', '~> 3.0.1'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'

  gem 'shotgun'
end