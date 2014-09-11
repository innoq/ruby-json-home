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

require 'logger'

require 'json_home'

module RubyJSONHome

  VERSION = '0.0.3'

end


if Kernel.const_defined?(:Rails)
  JSONHome.ignore_http_errors = Rails.env.development?
  JSONHome.logger = Rails.logger
else
  JSONHome.logger = Logger.new(STDOUT)
end
