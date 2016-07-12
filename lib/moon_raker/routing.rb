module MoonRaker
  module Routing
    module MapperExtensions
      def moon_raker(options = {})
        namespace 'moon_raker', path: MoonRaker.configuration.doc_base_url do
          get 'moon_raker_checksum', to: 'moon_raker#moon_raker_checksum', format: 'json'
          get 'guides', to: 'moon_raker#guides'
          get 'guides/:section', to: 'moon_raker#guides'
          constraints(version: /[^\/]+/, resource: /[^\/]+/, method: /[^\/]+/) do
            get(options.reverse_merge('(:version)/(:resource)/(:method)' => 'moon_raker#index', :as => :moon_raker))
          end
        end
      end
    end
  end
end

ActionDispatch::Routing::Mapper.send :include, MoonRaker::Routing::MapperExtensions
