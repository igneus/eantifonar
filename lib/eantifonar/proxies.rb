# encoding: UTF-8

require 'typhoeus'

module EAntifonar

  # Proxy provides an interface to obtain content from
  # an external service - website ebreviar.cz
  class HTTPProxy

    def initialize(config={})
      @site = config[:site]
    end

    def handle_request(method, orig_request, params)
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
      request = Typhoeus::Request.new(@site + "/" + orig_request.path, request_options)
      request.run

      forwarded_response = [request.response.code, request.response.headers, request.response.body]
      return forwarded_response
    end
  end
end