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

  ## Sinatra settings

  set :default_encoding, 'windows-1250'
  # set :public_folder, 'http://ebreviar.cz/' # doesn't work

  ## define routes

  get '*' do
    forward_request request, :get
  end

  get '*/*' do
    forward_request request, :get
  end

  post '*' do
    forward_request request, :post, params
  end

  ## methods

  def forward_request(orig_request, method, params={})
    p orig_request.env
    request = Typhoeus::Request.new(
      "breviar.sk/"+orig_request.path,
      method: orig_request.request_method.downcase.to_sym,
      headers: { 'User-Agent' => orig_request.env['HTTP_USER_AGENT'] },
      body: params
    )
    request.run

    return modify_page_content(request.response.body)
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

    return doc.to_html
  end

  ## 'main': start the server if ruby file executed directly

  run! if app_file == $0
end
