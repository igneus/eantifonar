require_relative 'spec_helper.rb'

require_relative '../app'

RSpec::Matchers.define :forward do |route|
  match do |app|
    app.forward? route
  end
end

describe EAntifonarApp do

  include Rack::Test::Methods

  # expected by Rack::Test, returns the tested application
  def app
    EAntifonarApp
  end

  it 'redirects / to an e-breviar route' do
    get '/'
    last_response.status.should be 302
    last_response.headers['Location'].should include '/cgi-bin/l.cgi'
  end

  it 'refuses simple path traversal attack' do
    get '/../Gemfile' # path relative to public
    last_response.status.should be 404
  end

  describe 'forwards some requests to an external breviary website:' do
    subject { @app = EAntifonarApp.new! } # Sinatra renames new to new!

    describe 'external stylesheet' do
      it { should forward '/ebreviar-cz.css' }
    end

    describe 'local static files' do
      it { should_not forward '/css/eantifonar.css' }
      it { should_not forward '/chants/pust_tyden5_1.png' }
      it { should_not forward '/js/chantplayer.js' }
    end

    describe 'external script requests' do
      it { should forward '/cgi-bin/l.cgi?qt=pdt&d=5&m=4&r=2014&p=mv&j=cz&c=cz' } # hour
      it { should forward '/cgi-bin/l.cgi?qt=pdnes&j=cz&c=cz' } # day overview and options
      it { should forward '/cgi-bin/l.cgi?qt=pdt&d=*&m=5&r=2014&j=cz&c=cz' } # month overview
    end

    describe 'unknown url' do
      it { should_not forward '/somewhere/something.html' }
    end
  end
end