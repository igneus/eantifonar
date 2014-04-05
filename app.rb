# encoding: UTF-8

require 'sinatra/base'
require 'nokogiri'
require 'mime/types'
require 'yaml'
require 'haml'
require 'log4r'

require 'data_mapper'

%w{config db_setup lyrictools decorator helpers proxies}.each do |r|
  require_relative File.join('lib', 'eantifonar', r)
end

class EAntifonarApp < Sinatra::Base

  include EAntifonar
  include EAntifonar::Helpers

  def initialize
    super()

    # absolute links to these domains will be modified
    @wrapped_domains = {}
    ['breviar.sk', 'ebreviar.cz'].each do |d|
      full = 'http://'+d
      @wrapped_domains[d] = {:full => full, :regex => Regexp.new('^'+full+'/*')}
    end

    EAntifonar.init_logging
    decorator_logger = Log4r::Logger['decorator']
    @decorator = Decorator.new decorator_logger

    @proxy = HTTPProxy.new site: 'breviar.sk'
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

  ## browsing database content

  get '/chant' do
    chant_list params
  end

  get '/chant/:id' do |id|
    id = id.to_i
    p id
    chant = Chant.get(id)
    if chant == nil then
      raise Sinatra::NotFound
    end

    haml :chant, :locals => { :chant => chant }
  end

  get '/chantsrc/*' do |path|
    p path
    chants = Chant.all(:src_path => path, :order => [:id.asc])
    if chants.empty? then
      raise Sinatra::NotFound
    end
    haml :'chant.list', :locals => { :title => path, :chants => chants }
  end

  ## forwarded routes

  get '/' do
    redirect '/cgi-bin/l.cgi?qt=pdnes&amp;j=cz&amp;c=cz', 302
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

  def chant_list(params)
    pieces_per_page = 50

    page = params[:page] or 1
    page = page.to_i
    page = 1 unless page > 0

    query = {
      :order => [:lyrics_cleaned.asc],
    }

    filter = {}

    if params[:filtered] then
      # values for the db query
      filter[:text] = params[:text] if params[:text].is_a? String and params[:text] != ''
      types = [:ant, :resp, :other].select {|t| params["type_#{t.to_s}"] }
      filter[:chant_type] = types if types.size > 0
      filter[:src_path] = params[:src_path] if params[:src_path].is_a? String and params[:src_path] != ''

      if filter.has_key? :text then
        filter[:text].split(' ').each do |chunk|
          query.update({ :lyrics_cleaned.like => "%#{chunk}%" })
        end
      end
      [:chant_type, :src_path].each do |field|
        query.update({ field => filter[field] }) if filter.has_key? field
      end
    end

    # values to generate the form
    unless filter.has_key? :text
      filter[:text] = ''
    else
      filter[:text] = params[:text]
    end
    filter[:src_path] = '' unless filter[:src_path]
    filter[:chant_type] = [] unless filter[:chant_type]

    STDERR.puts filter.inspect

    pieces = Chant.count(query) # total size
    pages = (pieces.to_f / pieces_per_page).ceil

    # limit output size
    query.update({
      :limit => pieces_per_page,

      # page 0 doesn't make sense, so we add 1 in the view
      # and substract it here to make pages start with 1 in the front-end
      :offset => (page - 1) * pieces_per_page
    })

    haml :'chant.list', :locals => {
      :title => 'Všechny zpěvy',

      :chants => Chant.all(query),
      :files => Chant.all(:fields => [:src_path], :unique => true, :order => [:src_path.asc]).collect {|c| c.src_path },
      :chants_count => pieces,

      :pages => pages,
      :filter => filter
    }
  end

  # finds and returns static content;
  # looks for local content and eventually returns it
  # (as a valid Sinatra response - the Array variant);
  # if it is not found, forwards the request to the external site
  def static_content(request)
    local_path = File.join('public', request.path)
    unless File.exist?(local_path) # TODO: unsafe!
      return forward_request(request, request.method, params)
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

    response = @proxy.handle_request method, orig_request, params
    code, headers, body = response

    if code == 404 then
      raise Sinatra::NotFound
    end

    # modify the response
    if html? body then
      orig_url = 'http://breviar.sk'+orig_request.path+'?'+::URI.encode_www_form(params)
      STDERR.puts orig_url
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
