require 'i18n'
require 'active_support/hash_with_indifferent_access'

require 'moon_raker/routing'
require 'moon_raker/markup'
require 'moon_raker/moon_raker_module'
require 'moon_raker/dsl_definition'
require 'moon_raker/configuration'
require 'moon_raker/method_description'
require 'moon_raker/resource_description'
require 'moon_raker/param_description'
require 'moon_raker/errors'
require 'moon_raker/error_description'
require 'moon_raker/see_description'
require 'moon_raker/validator'
require 'moon_raker/railtie'
require 'moon_raker/extractor'
require 'moon_raker/version'

if Rails.version.start_with?('3.0')
  warn 'Warning: moon_raker-rails is not going to support Rails 3.0 anymore in future versions'
end
