require 'sinatra/base'
require 'typhoeus'
require 'nokogiri'

require 'data_mapper'
require_relative 'lib/eantifonar/db_setup'

class EantifonarApp < Sinatra::Base

  def initialize
    super()

    # absolute links to these domains will be modified
    @wrapped_domains = {}
    ['breviar.sk', 'ebreviar.cz'].each do |d|
      full = 'http://'+d
      @wrapped_domains[d] = {:full => full, :regex => Regexp.new('^'+full+'/*')}
    end
  end

  ## define routes

  # our own public static content
  get '/eantifonar/chants/:file' do
    STDERR.puts 'triggered'
    content = File.read(File.join('public', 'chants', params[:file]))
    return [200, {'Content-Type' => 'image/png'}, content]
  end

  get '*' do
    forward_request request, :get, params
  end

  # TODO this route is maybe synonym to the previous?
  get '*/*' do
    forward_request request, :get, params
  end

  post '*' do
    forward_request request, :post, params
  end

  ## methods

  def forward_request(orig_request, method, params={})
    method = orig_request.request_method.downcase.to_sym

    # compose and run a request on the shadowed server
    request_options = {
      :method => method,
      :headers => { 'User-Agent' => orig_request.env['HTTP_USER_AGENT'] },
    }
    if method == :post then
      request_options[:body] = params
    else
      request_options[:params] = params
    end
    request = Typhoeus::Request.new("breviar.sk/"+orig_request.path, request_options)
    request.run

    # modify the response and send it to the client
    response_body = request.response.body
    if html? response_body then
      response_body = modify_page_content(response_body)
    else
    end

    response_headers = forwarded_params = copy_keys(request.response.headers, ['Date', 'Content-Type'])

    forwarded_response = [request.response.code, response_headers, response_body]
    return forwarded_response
  end

  def modify_page_content(content)

    doc = Nokogiri::HTML(content)

    # replace links
    doc.css('a').each do |a|
      next unless a['href'].is_a? String

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

    # tag antiphons
    doc.css('p > b > span.red').each do |span|
      if span.text.downcase.include? 'ant.' then
        p = span.parent.parent
        decorate_antiphon p
      end
    end

    return doc.to_html
  end


  def decorate_antiphon(node)
    node['class'] = 'eantifonar-antifona'
    ant_text = node.css('b').text # text together with the leading rubric

    # try to get pure antiphon text
    node.css('b').children.each do |c|
      if c.is_a? Nokogiri::XML::Text and c.text.strip.size > 0 then
        ant_text = c.text.strip
        break
      end
    end

    ant_text.gsub!('&nbsp;', ' ')

    chants = Chant.all(:lyrics_cleaned => ant_text)
    if chants.size > 0 then
      src = File.join('/eantifonar', 'chants', File.basename(chants.first.image_path))
      node.add_child "<img src=\"#{src}\">"
    else
      STDERR.puts "Chant not found for ant. '#{ant_text}'."
    end
  end

  # detects if the downloaded content is html
  # (weak detection sufficient for the web we are working with)
  def html?(response_body)
    response_body.start_with? '<!DOCTYPE'
  end

  # returns a new Hash containing only pairs with a key
  # included in a given list
  def copy_keys(hash, keys)
    r = {}
    keys.each do |k|
      if hash.include? k then
        r[k] = hash[k]
      end
    end
    return r
  end

  ## 'main': start the server if ruby file executed directly

  run! if app_file == $0
end
