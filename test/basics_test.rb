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

$LOAD_PATH << File.dirname(__FILE__)

require 'test_helper'

class BasicsTest < Minitest::Test

  def setup
    stub_request(:get, "www.example.com").
        with(:headers => { 'Accept' => 'application/json-home' }).
        to_return(:body => File.new(File.join(File.dirname(__FILE__), 'test-data.json')), :status => 200)
  end

  def test_simple_functionality
    jh = JSONHome.new("http://www.example.com")

    assert jh.uri?("http://example.org/rel/widgets"), "URI 'http://example.org/rel/widgets' should be defined"
    assert_equal("/widgets/", jh.uri("http://example.org/rel/widgets"))

    assert jh.uri?("http://example.org/rel/widget"), "URI 'http://example.org/rel/widget' should be defined"
    assert_equal("/widgets/4711", jh.uri("http://example.org/rel/widget", :widget_id => 4711))
    assert_equal("/widgets/1234", jh.uri("http://example.org/rel/widget", "widget_id" => 1234))
  end

end