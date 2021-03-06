#   Copyright 2014 innoQ Deutschland GmbH
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

  DEFAULT_NAMESPACE = 'http://helloworld.innoq.com'

  class << self
    attr_accessor :logger, :ignore_http_errors, :default_namespace, :use_additional_params, :socks_proxy
  end
  self.default_namespace = DEFAULT_NAMESPACE

  def initialize(base_uri, local_resources = nil)
    @base_uri  = URI.parse(base_uri)
    @resources = {}
    reload(local_resources)
  end

  def reload(local_resources = nil)
    net_http.start(@base_uri.host, @base_uri.port, :use_ssl => @base_uri.scheme == 'https') do |http|
      req = if local_resources.is_a?(Hash)
        r = net_http::Put.new(@base_uri.request_uri)
        r.body = JSON.generate('resources' => with_namespaces(local_resources))
        r['Content-Type'] = 'application/json'
        r
      else
        net_http::Get.new(@base_uri.request_uri)
      end
      req['Accept'] = 'application/json-home'
      res = http.request(req)
      if res.is_a?(Net::HTTPSuccess)
        @resources = JSON.parse(res.body)['resources'] || {}
        self.class.logger.debug("Found ForeignLinks: #{@resources.keys.inspect}") if self.class.logger
      else
        raise RuntimeError.new("HTTP error: '#{res.code} #{res.message}'")
      end
    end
  rescue Net::HTTPExceptions, Errno::ECONNREFUSED, RuntimeError => e
    if self.class.ignore_http_errors
#       puts e
      self.class.logger.error(e) if self.class.logger
      @resources = with_namespaces(local_resources || {})
    else
      raise e
    end
  end

  def uri(resource, params = {})
    self.class.uri(@resources, resource, params)
  end

  def uri?(resource)
    self.class.uri?(@resources, resource)
  end

  def self.uri(resources, resource, params = {})
    resource = with_namespace(resource)
    unless uri?(resources, resource)
      self.warn "Couldn't find valid JSON home data for '#{resource}'"
      return nil
    end

    params = params.inject({}) { |h, (k, v)| h.merge(k.to_s => v)  }
    data   = resources[resource.to_s]

    if data['href'].is_a?(String)
      uri = data['href']
      unknown_keys = params.keys
    elsif data['href-template'].is_a?(String)
      uri = data['href-template']
      unknown_keys = (params.keys - data['href-vars'].keys)
      self.warn "Unknown keys #{unknown_keys.inspect} in ForeignLinks#uri call" if unknown_keys.any?
      data['href-vars'].each do |key, type_uri|
        self.warn("Missing key '#{key}' in ForeignLinks#uri call (rel=#{resource})") unless params[key]
        uri = uri.gsub("{#{key}}", params[key].to_s)
      end
    end

    if self.use_additional_params and unknown_keys.any?
      additional_params = URI.encode_www_form params.select{|k, v| unknown_keys.include? k }
      if uri.include? '?'
        uri + '&' + additional_params
      else
        uri + '?' + additional_params
      end
    else
      uri
    end
  end

  def self.uri?(resources, resource)
    data = resources[self.with_namespace(resource)]
    data.is_a?(Hash) && (
      data['href'].is_a?(String) ||
          (data['href-template'].is_a?(String) && data['href-vars'].is_a?(Hash))
    )
  end

  protected

  def net_http
    if self.class.socks_proxy
      self.class.logger.debug "Using SOCKS proxy"
    end
    self.class.socks_proxy || Net::HTTP
  end

  def self.with_namespace(resource)
    if resource.to_s.include?('/')
      resource.to_s
    else
      [self.default_namespace, resource].join('/')
    end
  end

  # appends the default namespace to each resource given in :local_resources
  def with_namespaces(local_resources)
    local_resources.each_with_object({}) do |(k, v), memo|
      memo[self.class.with_namespace(k)] = v
    end
  end

  def self.warn(msg)
    self.logger.warn msg if self.logger
  end

end
