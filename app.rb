# encoding: UTF-8

require 'sinatra/base'
require 'nokogiri'
require 'mime/types'
require 'yaml'
require 'haml'
require 'log4r'

require 'data_mapper'

%w{config model lyrictools ebreviarpage decorator helpers proxies}.each do |r|
  require_relative File.join('lib', 'eantifonar', r)
end

class EAntifonarApp < Sinatra::Base

  include EAntifonar
  include EAntifonar::Helpers

  def initialize
    super()

    # absolute links to these domains will be modified
    @wrapped_domains = {}
    ['lh.kbs.sk', 'breviar.cz'].each do |d|
      full = 'http://'+d
      @wrapped_domains[d] = {:full => full, :regex => Regexp.new('^'+full+'/*')}
    end

    EAntifonar.init_logging
    decorator_logger = Log4r::Logger['decorator']
    @decorator = Decorator.new decorator_logger, self.class.development?

    @proxy = HTTPProxy.new site: 'https://lh.kbs.sk'
  end

  Encoding.default_external = 'UTF-8' if "1.9".respond_to?(:encoding)
  set :haml, :default_encoding => 'utf-8'
  set :haml, :layout => :_layout
  set :haml, :format => :xhtml

  ## routes for static content

  get /\.(png|ico|js)$/ do
    return static_content request
  end

  get '/about.html' do
    rev = nil
    rev_file = File.join('public', 'REVISION')
    if File.exist? rev_file then
      File.open(rev_file) {|f| rev = f.gets }
    end

    haml :about, :locals => {:git_revision => rev}
  end

  ## forwarded routes

  get '/' do
    redirect '/cgi-bin/l.cgi?qt=pdnes&j=cz&c=cz', 302
  end

  get '/robots.txt' do
    erb :robots, content_type: 'text/plain'
  end

  get '*' do
    forward_request request, :get, params
  end

  post '*' do
    forward_request request, :post, params
  end

  ## "system" routes

  not_found do
    haml :error404
  end

  ## methods

  # finds and returns static content;
  # looks for local content and eventually returns it
  # (as a valid Sinatra response - the Array variant);
  # if it is not found, forwards the request to the external site
  def static_content(request)
    local_path = File.join('public', request.path)
    unless File.exist?(local_path) # TODO: unsafe!
      return forward_request(request, request.request_method, params)
    end

    content = File.read(local_path)
    content_type = MIME::Types.type_for(local_path).first.to_s # "" if no matching type is found
    return [200, { 'Content-Type' => content_type }, content]
  end

  # determine if a request to the given route should be forwarded
  # to the external site or not
  def forward?(route)
    if route.start_with? '/cgi-bin/l.cgi' then
      return true
    end

    whitelist = %w{
      /breviar.css
      /ebreviar-cz.css
    }
    if whitelist.include? route then
      return true
    end

    # by default don't forward
    return false
  end

  # forwards a request to the external site,
  # returns a valid response as expected by Sinatra (the Array variant)
  def forward_request(orig_request, method, params={})
    unless forward? orig_request.path
      raise Sinatra::NotFound
    end

    response = @proxy.handle_request method, orig_request, request.env['rack.request.query_hash']
    code, headers, body = response

    if code == 404 then
      raise Sinatra::NotFound
    end

    # modify the response
    if html? body then
      orig_url = 'http://breviar.sk'+orig_request.path+'?'+::URI.encode_www_form(params)
      body = modify_page_content(body, orig_url)
    end

    # drop most of the headers
    headers = copy_keys(headers, ['Date', 'Content-Type'])

    return [code, headers, body]
  end

  def modify_page_content(content, request_path)

    doc = Nokogiri::HTML(content)
    doc.encoding = 'utf-8'

    # replace direct internal links so that the user doesn't leave eantifonar accidentally
    doc.css('a').each do |a|
      next unless a['href'].is_a? String
      next if a.parent['class'] == 'patka'

      if a['href'].start_with?('http://') then
        puts "examining link #{a['href']}"
        @wrapped_domains.each_pair do |d, d_data|
          if a['href'].start_with?(d_data[:full]) then
            new_href = a['href'].sub(d_data[:regex], '/')
            puts "link #{a['href']} -> #{new_href}"
            a['href'] = new_href

            break
          end
        end
      end
    end

    @decorator.decorate doc, request_path # insert scores etc.
    return doc.to_html(:encoding => 'utf-8')
  end

  ## 'main': start the server if ruby file executed directly

  run! if app_file == $0
end
