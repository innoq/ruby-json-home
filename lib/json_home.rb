#   Copyright 2011 innoQ Deutschland GmbH
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'net/http'
require 'json'

class JSONHome

  attr_reader :base_uri

  class << self
    attr_accessor :logger, :ignore_http_errors
  end

  def initialize(base_uri, local_resources = nil)
    @base_uri = URI.parse(base_uri)
    @resources = {}
    reload(local_resources)
  end

  def reload(local_resources = nil)
    Net::HTTP.start(base_uri.host, base_uri.port) do |http|
      req = if local_resources.is_a?(Hash)
        r = Net::HTTP::Put.new(base_uri.request_uri)
        r.body = JSON.generate("resources" => local_resources.each_with_object({}) { |(k, v), memo|
            k = "http://helloworld.innoq.com/#{k}" unless k.to_s.include?("/")
            memo[k] = v
          })
        r["Content-Type"] = "application/json"
        r
      else
        Net::HTTP::Get.new(base_uri.request_uri)
      end
      req['Accept'] = "application/json-home"
      res = http.request(req)
      if res.is_a?(Net::HTTPSuccess)
        @resources = JSON.parse(res.body)["resources"] || {}
        JSONHome.logger && JSONHome.logger.info("Found ForeignLinks: #{@resources.keys.inspect}")
      else
        raise RuntimeError.new("HTTP error: '#{res.code} #{res.message}'")
      end
    end
  rescue Net::HTTPExceptions, Errno::ECONNREFUSED, RuntimeError => e
    if JSONHome.ignore_http_errors
      puts e
      JSONHome.logger && JSONHome.logger.error(e)
      @resources = {}
    else
      raise e
    end
  end

  def uri(resource, params = {})
    JSONHome.uri(@resources, resource, params)
  end

  def uri?(resource)
    JSONHome.uri?(@resources, resource)
  end

  def self.uri(resources, resource, params = {})
    unless uri?(resources, resource)
      JSONHome.logger && JSONHome.logger.warn("Couldn't find valid JSON home data for '#{resource}'")
      return nil
    end

    params = params.inject({}) { |h, (k, v)| h.merge(k.to_s => v)  }

    data = resources[resource.to_s]
    if data["href"].is_a?(String)
      data["href"].to_s
    elsif data["href-template"].is_a?(String)
      uri = data["href-template"].to_s
      unknown_keys = (params.keys - data["href-vars"].keys)
      JSONHome.logger && JSONHome.logger.warn("Unknown keys #{unknown_keys.inspect} in ForeignLinks#uri call") if unknown_keys.any?
      data["href-vars"].each do |key, type_uri|
        JSONHome.logger && JSONHome.logger.warn("Missing key '#{key}' in ForeignLinks#uri call") unless params[key]
        uri = uri.gsub("{#{key}}", params[key].to_s)
      end
      uri
    end
  end

  def self.uri?(resources, resource)
    data = resources[resource.to_s]
    data.is_a?(Hash) && (
      data["href"].is_a?(String) ||
          (data["href-template"].is_a?(String) && data["href-vars"].is_a?(Hash))
    )
  end

end