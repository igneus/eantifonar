require 'sinatra/base'
require 'typhoeus'
require 'nokogiri'

class EantifonarApp < Sinatra::Base

  def initialize
    super()

    # absolute links to these domains will be modified
    @wrapped_domains = {}
    ['breviar.sk', 'ebreviar.cz'].each do |d|
      full = 'http://'+d
      @wrapped_domains[d] = {:full => full, :regex => Regexp.new('^'+full+'/*')}
    end

    @domain = 'localhost:4567'
  end

  ## define routes

  get '*' do
    forward_request request, :get, params
  end

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
      puts "--H #{orig_request.path}"
      response_body = modify_page_content(response_body)
    else
      puts "--S #{orig_request.path}"
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
    doc.css('p > b').each do |b|
      if b.text.include? 'ant.' then
        b.parent['class'] = 'eantifonar-antifona'
      end
    end

    return doc.to_html
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