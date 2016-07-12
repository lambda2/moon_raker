# MoonRaker DSL functions.

module MoonRaker
  # DSL is a module that provides #api, #error, #param, #error.
  module DSL
    module Base
      attr_reader :moon_raker_resource_descriptions, :api_params

      private

      def _moon_raker_dsl_data
        @_moon_raker_dsl_data ||= _moon_raker_dsl_data_init
      end

      def _moon_raker_dsl_data_clear
        # p "CLEAR CALLED, clearing api_args: #{@_moon_raker_dsl_data [:api_args]}" unless @_moon_raker_dsl_data[:api_args].blank?
        @_moon_raker_dsl_data = nil
      end

      def _moon_raker_dsl_data_init
        @_moon_raker_dsl_data = {
          api: false,
          api_args: [],
          api_from_routes: nil,
          errors: [],
          params: [],
          headers: [],
          resouce_id: nil,
          short_description: nil,
          description: nil,
          examples: [],
          see: [],
          formats: nil,
          api_versions: [],
          meta: nil,
          show: true
        }
      end
    end

    module Resource
      # by default, the resource id is derived from controller_name
      # it can be overwritten with.
      #
      #    resource_id "my_own_resource_id"
      def resource_id(resource_id)
        MoonRaker.set_resource_id(@controller, resource_id)
      end

      def name(name)
        _moon_raker_dsl_data[:resource_name] = name
      end

      def api_base_url(url)
        _moon_raker_dsl_data[:api_base_url] = url
      end

      def short(short)
        _moon_raker_dsl_data[:short_description] = short
      end
      alias short_description short

      def path(path)
        _moon_raker_dsl_data[:path] = path
      end

      def app_info(app_info)
        _moon_raker_dsl_data[:app_info] = app_info
      end
    end

    module Action
      def def_param_group(name, &block)
        MoonRaker.add_param_group(self, name, &block)
      end

      #
      #   # load paths from routes and don't provide description
      #   api
      #
      def api(method, path, desc = nil, options = {}) #:doc:
        # p "[PIPI...] registering #{method} #{path}, (#{desc}) #{options}"
        # p "[...PIPI] in api method (#{MoonRaker.active_dsl?})"
        return unless MoonRaker.active_dsl?
        # p "[PIPI] passed !"
        _moon_raker_dsl_data[:api] = true
        _moon_raker_dsl_data[:api_args] << [method, path, desc, options]
      end

      #   # load paths from routes
      #   api! "short description",
      #
      def api!(desc = nil, options = {}) #:doc:
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:api] = true
        _moon_raker_dsl_data[:api_from_routes] = { desc: desc, options: options }
      end

      # Reference other similar method
      #
      #   api :PUT, '/articles/:id'
      #   see "articles#create"
      #   def update; end
      def see(*args)
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:see] << args
      end

      # Show some example of what does the described
      # method return.
      def example(example) #:doc:
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:examples] << (example.is_a?(String) ? example.strip_heredoc : example)
      end

      # Determine if the method should be included
      # in the documentation
      def show(show)
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:show] = show
      end

      # Describe whole resource
      #
      # Example:
      # api :desc => "Show user profile", :path => "/users/", :version => '1.0 - 3.4.2012'
      # param :id, Fixnum, :desc => "User ID", :required => true
      # desc <<-EOS
      #   Long description...
      # EOS
      def resource_description(_options = {}, &block) #:doc:
        return unless MoonRaker.active_dsl?
        raise ArgumentError, 'Block expected' unless block_given?

        dsl_data = ResourceDescriptionDsl.eval_dsl(self, &block)
        versions = dsl_data[:api_versions]
        @moon_raker_resource_descriptions = versions.map do |version|
          MoonRaker.define_resource_description(self, version, dsl_data)
        end
        MoonRaker.set_controller_versions(self, versions)
      end
    end

    module Common
      def api_versions(*versions)
        _moon_raker_dsl_data[:api_versions].concat(versions)
      end
      alias api_version api_versions

      # Describe the next method.
      #
      # Example:
      #   desc "print hello world"
      #   def hello_world
      #     puts "hello world"
      #   end
      #
      def desc(description) #:doc:
        return unless MoonRaker.active_dsl?
        raise 'Double method description.' if _moon_raker_dsl_data[:description]
        _moon_raker_dsl_data[:description] = description
      end
      alias description desc
      alias full_description desc

      # describe next method with document in given path
      # in convension, these doc located under "#{Rails.root}/doc"
      # Example:
      # document "hello_world.md"
      # def hello_world
      #   puts "hello world"
      # end
      def document(path)
        content = File.open(File.join(Rails.root, MoonRaker.configuration.doc_path, path)).read
        desc content
      end

      # Describe available request/response formats
      #
      #   formats ['json', 'jsonp', 'xml']
      def formats(formats) #:doc:
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:formats] = formats
      end

      # Describe additional metadata
      #
      #   meta :author => { :name => 'John', :surname => 'Doe' }
      def meta(meta) #:doc:
        _moon_raker_dsl_data[:meta] = meta
      end

      # Describe possible errors
      #
      # Example:
      #   error :desc => "speaker is sleeping", :code => 500, :meta => [:some, :more, :data]
      #   error 500, "speaker is sleeping"
      #   def hello_world
      #     return 500 if self.speaker.sleeping?
      #     puts "hello world"
      #   end
      #
      def error(code_or_options, desc = nil, options = {}) #:doc:
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:errors] << [code_or_options, desc, options]
      end

      def _moon_raker_define_validators(description)
        # [re]define method only if validation is turned on
        if description && (MoonRaker.configuration.validate == true ||
                           MoonRaker.configuration.validate == :implicitly ||
                           MoonRaker.configuration.validate == :explicitly)

          _moon_raker_save_method_params(description.method, description.params)

          unless instance_methods.include?(:moon_raker_validations)
            define_method(:moon_raker_validations) do
              method_params = self.class._moon_raker_get_method_params(action_name)

              if MoonRaker.configuration.validate_presence?
                method_params.each do |_, param|
                  # check if required parameters are present
                  raise ParamMissing.new(param) if param.required && !params.has_key?(param.name)
                end
              end

              if MoonRaker.configuration.validate_value?
                method_params.each do |_, param|
                  # params validations
                  param.validate(params[:"#{param.name}"]) if params.key?(param.name)
                end
              end

              # Only allow params passed in that are defined keys in the api
              # Auto skip the default params (format, controller, action)
              if MoonRaker.configuration.validate_key?
                params.reject { |k, _| %w(format controller action).include?(k.to_s) }.each_key do |param|
                  # params allowed
                  raise UnknownParam, param if method_params.select { |_, p| p.name.to_s == param.to_s }.empty?
                end
              end

              if MoonRaker.configuration.process_value?
                @api_params ||= {}
                method_params.each do |_, param|
                  # params processing
                  @api_params[param.as] = param.process_value(params[:"#{param.name}"]) if params.key?(param.name)
                end
              end
            end
          end

          if MoonRaker.configuration.validate == :implicitly || MoonRaker.configuration.validate == true
            old_method = instance_method(description.method)

            define_method(description.method) do |*args|
              moon_raker_validations

              # run the original method code
              old_method.bind(self).call(*args)
            end
          end

        end
      end

      def _moon_raker_save_method_params(method, params)
        @method_params ||= {}
        @method_params[method] = params
      end

      def _moon_raker_get_method_params(method)
        @method_params[method]
      end

      # Describe request header.
      #  Headers can't be validated with config.validate_presence = true
      #
      # Example:
      #   header 'ClientId', "client-id"
      #   def show
      #     render :text => headers['HTTP_CLIENT_ID']
      #   end
      #
      def header(header_name, description, options = {}) #:doc
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:headers] << {
          name: header_name,
          description: description,
          options: options
        }
      end
    end

    # this describes the params, it's in separate module because it's
    # used in Validators as well
    module Param
      # Describe method's route parameter
      #
      # Example:
      #   route_param :greeting, String, :desc => "arbitrary text", :required => true
      #   def hello_world(greeting)
      #     puts greeting
      #   end
      #
      # def route_param(param_name, validator, desc_or_options = nil, options = {}, &block) #:doc:
      #   return unless MoonRaker.active_dsl?
      #   _moon_raker_dsl_data[:route_params] << [param_name,
      #                                 validator,
      #                                 desc_or_options,
      #                                 options.merge(:param_group => @_current_param_group),
      #                                 block]
      # end

      # Describe method's parameter
      #
      # Example:
      #   param :greeting, String, :desc => "arbitrary text", :required => true
      #   def hello_world(greeting)
      #     puts greeting
      #   end
      #
      def param(param_name, validator, desc_or_options = nil, options = {}, &block) #:doc:
        return unless MoonRaker.active_dsl?
        _moon_raker_dsl_data[:params] << [param_name,
                                      validator,
                                      desc_or_options,
                                      options.merge(param_group: @_current_param_group),
                                      block]
      end

      # Reuses param group for this method. The definition is looked up
      # in scope of this controller. If the group was defined in
      # different controller, the second param can be used to specify it.
      # when using action_aware parmas, you can specify :as =>
      # :create or :update to explicitly say how it should behave
      def param_group(name, scope_or_options = nil, options = {})
        if scope_or_options.is_a? Hash
          options.merge!(scope_or_options)
          scope = options[:scope]
        else
          scope = scope_or_options
        end
        scope ||= _default_param_group_scope

        @_current_param_group = {
          scope: scope,
          name: name,
          options: options,
          from_concern: scope.moon_raker_concern?
        }
        instance_exec(&MoonRaker.get_param_group(scope, name))
      ensure
        @_current_param_group = nil
      end

      # where the group definition should be looked up when no scope
      # given. This is expected to return a controller.
      def _default_param_group_scope
        self
      end
    end

    module Controller
      include MoonRaker::DSL::Base
      include MoonRaker::DSL::Common
      include MoonRaker::DSL::Action
      include MoonRaker::DSL::Param

      # defines the substitutions to be made in the API paths deifned
      # in concerns included. For example:
      #
      # There is this method defined in concern:
      #
      #    api GET ':controller_path/:id'
      #    def show
      #      # ...
      #    end
      #
      # If you include the concern into some controller, you can
      # specify the value for :controller_path like this:
      #
      #      moon_raker_concern_subst(:controller_path => '/users')
      #      include ::Concerns::SampleController
      #
      # The resulting path will be '/users/:id'.
      #
      # It has to be specified before the concern is included.
      #
      # If not specified, the default predefined substitions are
      #
      #    {:conroller_path => controller.controller_path,
      #     :resource_id  => `resource_id_from_moon_raker` }
      def moon_raker_concern_subst(subst_hash)
        _moon_raker_concern_subst.merge!(subst_hash)
      end

      def _moon_raker_concern_subst
        @_moon_raker_concern_subst ||= { controller_path: controller_path,
                                     resource_id: MoonRaker.get_resource_name(self) }
      end

      def _moon_raker_perform_concern_subst(string)
        _moon_raker_concern_subst.reduce(string) do |ret, (key, val)|
          ret.gsub(":#{key}", val)
        end
      end

      def moon_raker_concern?
        false
      end

      # create method api and redefine newly added method
      def method_added(method_name) #:doc:
        super
        # p "Adding method #{method_name}" if !_moon_raker_dsl_data[:api_args].blank?
        return if !MoonRaker.active_dsl? || !_moon_raker_dsl_data[:api]

        return if _moon_raker_dsl_data[:api_args].blank? && _moon_raker_dsl_data[:api_from_routes].blank?

        # remove method description if exists and create new one
        MoonRaker.remove_method_description(self, _moon_raker_dsl_data[:api_versions], method_name)
        description = MoonRaker.define_method_description(self, method_name, _moon_raker_dsl_data)

        _moon_raker_dsl_data_clear
        _moon_raker_define_validators(description)
      ensure
        _moon_raker_dsl_data_clear
      end
    end

    module Concern
      include MoonRaker::DSL::Base
      include MoonRaker::DSL::Common
      include MoonRaker::DSL::Action
      include MoonRaker::DSL::Param

      # the concern was included into a controller
      def included(controller)
        super
        _moon_raker_concern_data.each do |method_name, _moon_raker_dsl_data|
          # remove method description if exists and create new one
          description = MoonRaker.define_method_description(controller, method_name, _moon_raker_dsl_data)
          controller._moon_raker_define_validators(description)
        end
      end

      def _moon_raker_concern_data
        @_moon_raker_concern_data ||= []
      end

      def moon_raker_concern?
        true
      end

      # create method api and redefine newly added method
      def method_added(method_name) #:doc:
        super

        return if !MoonRaker.active_dsl? || !_moon_raker_dsl_data[:api]

        _moon_raker_concern_data << [method_name, _moon_raker_dsl_data.merge(from_concern: true)]
      ensure
        _moon_raker_dsl_data_clear
      end
    end

    class ResourceDescriptionDsl
      include MoonRaker::DSL::Base
      include MoonRaker::DSL::Common
      include MoonRaker::DSL::Resource
      include MoonRaker::DSL::Param

      def initialize(controller)
        @controller = controller
      end

      def _eval_dsl(&block)
        instance_eval(&block)
        _moon_raker_dsl_data
      end

      # evaluates resource description DSL and returns results
      def self.eval_dsl(controller, &block)
        dsl_data = new(controller)._eval_dsl(&block)
        if dsl_data[:api_versions].empty?
          dsl_data[:api_versions] = MoonRaker.controller_versions(controller)
        end
        dsl_data
      end
    end
  end # module DSL
end # module MoonRaker
