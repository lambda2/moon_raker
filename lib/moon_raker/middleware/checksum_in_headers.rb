# Middleware for rails app that adds checksum of JSON in the response headers
# which can help client to realize when JSON has changed
#
# Add the following to your application.rb
#   require 'moon_raker/middleware/checksum_in_headers'
#   # Add JSON checksum in headers for smarter caching
#   config.middleware.use "MoonRaker::Middleware::ChecksumInHeaders"
#
# And in your moon_raker initializer allow checksum calculation
#   MoonRaker.configuration.update_checksum = true
# and reload documentation
#   MoonRaker.reload_documentation
#
# By default the header is added to requests on /api and /moon_raker only
# It can be changed with
#   MoonRaker.configuration.checksum_path = ['/prefix/api']
# If set to nil the header is added always

module MoonRaker
  module Middleware
    class ChecksumInHeaders
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)
        if !MoonRaker.configuration.checksum_path || env['PATH_INFO'].start_with?(*MoonRaker.configuration.checksum_path)
          headers['MoonRaker-Checksum'] = MoonRaker.checksum
        end
        [status, headers, body]
      end
    end
  end
end
