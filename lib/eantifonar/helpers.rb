# encoding: UTF-8

module EAntifonar

  module Helpers

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
  end
end