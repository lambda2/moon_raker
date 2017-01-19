module MoonRaker
  # method parameter description
  #
  # name - method name (show)
  # desc - description
  # required - boolean if required
  # validator - Validator::BaseValidator subclass
  class ParamDescription
    attr_reader :method_description, :name, :desc, :allow_nil, :validator, :options, :metadata, :show, :as, :validations
    attr_accessor :parent, :required

    def self.from_dsl_data(method_description, args)
      param_name, validator, desc_or_options, options, block = args
      MoonRaker::ParamDescription.new(method_description,
                                   param_name,
                                   validator,
                                   desc_or_options,
                                   options,
                                   &block)
    end

    def initialize(method_description, name, validator, desc_or_options = nil, options = {}, &block)
      if desc_or_options.is_a?(Hash)
        options = options.merge(desc_or_options)
      elsif desc_or_options.is_a?(String)
        options[:desc] = desc_or_options
      elsif !desc_or_options.nil?
        raise ArgumentError, 'param description: expected description or options as 3rd parameter'
      end

      options.symbolize_keys!

      # we save options to know what was passed in DSL
      @options = options
      if @options[:param_group]
        @from_concern = @options[:param_group][:from_concern]
      end

      @method_description = method_description
      @name = concern_subst(name)
      @as = options[:as] || @name
      @desc = preformat_text(@options[:desc])

      @parent = @options[:parent]
      @metadata = @options[:meta]

      @required = is_required?

      @show = if @options.key? :show
                @options[:show]
              else
                true
      end

      @allow_nil = @options[:allow_nil] || false

      action_awareness

      if validator
        @validator = Validator::BaseValidator.find(self, validator, @options, block)
        raise "Validator for #{validator} not found." unless @validator
      end

      @validations = Array(options[:validations]).map {|v| concern_subst(MoonRaker.markup_to_html(v)) }
    end

    def from_concern?
      method_description.from_concern? || @from_concern
    end

    def validate(value)
      return true if @allow_nil && value.nil?
      if (!@allow_nil && value.nil?) || !@validator.valid?(value)
        error = @validator.error
        error = ParamError.new(error) unless error.is_a? StandardError
        raise error
      end
    end

    def process_value(value)
      if @validator.respond_to?(:process_value)
        @validator.process_value(value)
      else
        value
      end
    end

    def full_name
      name_parts = parents_and_self.map { |p| p.name if p.show }.compact
      return name.to_s if name_parts.blank?
      ([name_parts.first] + name_parts[1..-1].map { |n| "[#{n}]" }).join('')
    end

    # returns an array of all the parents: starting with the root parent
    # ending with itself
    def parents_and_self
      ret = []
      ret.concat(parent.parents_and_self) if parent
      ret << self
      ret
    end

    def to_json(lang = nil)
      hash = { :name => name.to_s,
               :full_name => full_name,
               :description => preformat_text(MoonRaker.app.translate(@options[:desc], lang)),
               :required => required,
               :allow_nil => allow_nil,
               :validator => validator.to_s,
               :expected_type => validator.expected_type,
               :metadata => metadata,
               :show => show,
               :validations => validations }
      if sub_params = validator.params_ordered
        hash[:params] = sub_params.map { |p| p.to_json(lang) }
      end
      hash
    end

    def merge_with(other_param_desc)
      if validator && other_param_desc.validator
        begin
          validator.merge_with(other_param_desc.validator)
        rescue Exception => e
          puts "Unable to merge #{e}"
          self.validator ||= other_param_desc.validator
        end
      else
        self.validator ||= other_param_desc.validator
      end
      self
    end

    # merge param descripsiont. Allows defining hash params on more places
    # (e.g. in param_groups). For example:
    #
    #     def_param_group :user do
    #       param :user, Hash do
    #         param :name, String
    #       end
    #     end
    #
    #     param_group :user
    #     param :user, Hash do
    #       param :password, String
    #     end
    def self.unify(params)
      ordering = params.map(&:name)
      params.group_by(&:name).map do |_name, param_descs|
        p "[#{_name}] Reduced params: #{param_descs.reduce(&:merge_with)}"
        param_descs.reduce(&:merge_with)
      end.sort_by { |param| ordering.index(param.name) }
    end

    # action awareness is being inherited from ancestors (in terms of
    # nested params)
    def action_aware?
      if @options.key?(:action_aware)
        return @options[:action_aware]
      elsif @parent
        @parent.action_aware?
      else
        false
      end
    end

    def as_action
      if @options[:param_group] && @options[:param_group][:options] &&
         @options[:param_group][:options][:as]
        @options[:param_group][:options][:as].to_s
      elsif @parent
        @parent.as_action
      else
        @method_description.method
      end
    end

    # makes modification that are based on the action that the param
    # is defined for. Typical for required and allow_nil variations in
    # crate/update actions.
    def action_awareness
      if action_aware?
        unless @options.key?(:allow_nil)
          @allow_nil = if @required
                         false
                       else
                         true
                       end
        end
        @required = false if as_action != 'create'
      end
    end

    def concern_subst(string)
      return string if string.nil? || !from_concern?

      original = string
      string = ":#{original}" if original.is_a? Symbol

      replaced = method_description.resource.controller._moon_raker_perform_concern_subst(string)

      return original if replaced == string
      return replaced.to_sym if original.is_a? Symbol
      replaced
    end

    def preformat_text(text)
      concern_subst(MoonRaker.markup_to_html(text || ''))
    end

    def is_required?
      if @options.has_key?(:required)
        if (@options[:required] == true) || (@options[:required] == false)
          @options[:required]
        else
          Array(@options[:required]).include?(@method_description.method.to_sym)
        end
      else
        MoonRaker.configuration.required_by_default?
      end
    end

  end
end
