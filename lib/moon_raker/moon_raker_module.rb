require 'moon_raker/helpers'
require 'moon_raker/application'

module MoonRaker
  extend MoonRaker::Helpers

  def self.app
    @application ||= MoonRaker::Application.new
  end

  def self.to_json(version = nil, resource_name = nil, method_name = nil, lang = nil)
    version ||= MoonRaker.configuration.default_version
    app.to_json(version, resource_name, method_name, lang)
  end

  # all calls delegated to MoonRaker::Application instance
  def self.method_missing(method, *args, &block)
    app.respond_to?(method) ? app.send(method, *args, &block) : super
  end

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.debug(message)
    puts message if MoonRaker.configuration.debug
  end

  # get application description for given or default version
  def self.app_info(version = nil)
    if app_info_version_valid? version
      MoonRaker.markup_to_html(configuration.app_info[version])
    elsif app_info_version_valid? MoonRaker.configuration.default_version
      MoonRaker.markup_to_html(configuration.app_info[MoonRaker.configuration.default_version])
    else
      'Another API description'
    end
  end

  def self.api_base_url(version = nil)
    if api_base_url_version_valid? version
      configuration.api_base_url[version]
    elsif api_base_url_version_valid? MoonRaker.configuration.default_version
      configuration.api_base_url[MoonRaker.configuration.default_version]
    else
      '/api'
    end
  end

  def self.app_info_version_valid?(version)
    version && configuration.app_info.key?(version)
  end

  def self.api_base_url_version_valid?(version)
    version && configuration.api_base_url.key?(version)
  end

  def self.record(record)
    MoonRaker::Extractor.start record
  end
end
