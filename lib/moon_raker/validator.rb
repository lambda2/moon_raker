# -*- coding: utf-8 -*-


module MoonRaker
  module Validator
    # to create new validator, inherit from MoonRaker::Validator::Base
    # and implement class method build and instance method validate
    class BaseValidator
      attr_accessor :param_description

      def initialize(param_description)
        @param_description = param_description
      end

      def self.inherited(subclass)
        @validators ||= []
        @validators.insert 0, subclass
      end

      # find the right validator for given options
      def self.find(param_description, argument, options, block)
        @validators.each do |validator_type|
          validator = validator_type.build(param_description, argument, options, block)
          return validator if validator
        end
        nil
      end

      # check if value is valid
      def valid?(value)
        if validate(value)
          @error_value = nil
          true
        else
          @error_value = value
          false
        end
      end

      def param_name
        @param_description.name
      end

      # validator description
      def description
        'TODO: validator description'
      end

      def error
        ParamInvalid.new(param_name, @error_value, description)
      end

      def to_s
        description
      end

      def to_json
        description
      end

      # what type is expected, mostly string
      # this information is used in cli client
      # thor supported types :string, :hash, :array, :numeric, or :boolean
      def expected_type
        'string'
      end

      def merge_with(other_validator)
        raise NotImplementedError, "Dont know how to merge #{inspect} with #{other_validator.inspect}"
      end

      def params_ordered
        nil
      end
    end

    # validate arguments type
    class TypeValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @type = argument
      end

      def validate(value)
        return false if value.nil?
        value.is_a? @type
      end

      def self.build(param_description, argument, _options, block)
        if argument.is_a?(Class) && (argument != Hash || block.nil?)
          new(param_description, argument)
        end
      end

      def description
        "Must be #{@type}"
      end

      def expected_type
        if @type.ancestors.include? Hash
          'hash'
        elsif @type.ancestors.include? Array
          'array'
        elsif @type.ancestors.include? Numeric
          'numeric'
        else
          'string'
        end
      end
    end

    # validate arguments value with regular expression
    class RegexpValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @regexp = argument
      end

      def validate(value)
        value =~ @regexp
      end

      def self.build(param_description, argument, _options, _proc)
        new(param_description, argument) if argument.is_a? Regexp
      end

      def description
        "Must match regular expression <code>/#{@regexp.source}/</code>."
      end
    end

    # arguments value must be one of given in array
    class EnumValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @array = argument
      end

      def validate(value)
        @array.include?(value)
      end

      def self.build(param_description, argument, _options, _proc)
        new(param_description, argument) if argument.is_a?(Array)
      end

      def description
        string = @array.map { |value| "<code>#{value}</code>" }.join(', ')
        "Must be one of: #{string}."
      end
    end

    # arguments value must be an array
    class ArrayValidator < MoonRaker::Validator::BaseValidator
      def initialize(param_description, argument, options = {})
        super(param_description)
        @type = argument
        @items_type = options[:of]
        @items_enum = options[:in]
      end

      def validate(values)
        return false unless process_value(values).respond_to?(:each) && !process_value(values).is_a?(String)
        process_value(values).all? { |v| validate_item(v) }
      end

      def process_value(values)
        values || []
      end

      def description
        "Must be an array of #{items}"
      end

      def expected_type
        'array'
      end

      def self.build(param_description, argument, options, block)
        if argument == Array && !block.is_a?(Proc)
          new(param_description, argument, options)
        end
      end

      private

      def enum
        @items_enum = Array(@items_enum.call) if @items_enum.is_a?(Proc)
        @items_enum
      end

      def validate_item(value)
        has_valid_type?(value) &&
          is_valid_value?(value)
      end

      def has_valid_type?(value)
        if @items_type
          value.is_a?(@items_type)
        else
          true
        end
      end

      def is_valid_value?(value)
        if enum
          enum.include?(value)
        else
          true
        end
      end

      def items
        if enum
          enum.inspect
        else
          @items_type || 'any type'
        end
      end
    end

    class ArrayClassValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @array = argument
      end

      def validate(value)
        @array.include?(value.class)
      end

      def self.build(param_description, argument, _options, block)
        if argument.is_a?(Array) && argument.first.class == Class && !block.is_a?(Proc)
          new(param_description, argument)
        end
      end

      def description
        "Must be one of: #{@array.join(', ')}."
      end
    end

    class ProcValidator < BaseValidator
      def initialize(param_description, argument)
        super(param_description)
        @proc = argument
      end

      def validate(value)
        (@help = @proc.call(value)) === true
      end

      def self.build(param_description, argument, _options, _proc)
        new(param_description, argument) if argument.is_a?(Proc) && argument.arity == 1
      end

      def error
        ParamInvalid.new(param_name, @error_value, @help)
      end

      def description
        ''
      end
    end

    class HashValidator < BaseValidator
      include MoonRaker::DSL::Base
      include MoonRaker::DSL::Param

      def self.build(param_description, argument, options, block)
        new(param_description, block, options[:param_group]) if block.is_a?(Proc) && block.arity <= 0 && argument == Hash
      end

      def initialize(param_description, argument, param_group)
        super(param_description)
        @proc = argument
        @param_group = param_group
        instance_exec(&@proc)
        # specifying action_aware on Hash influences the child params,
        # not the hash param itself: assuming it's required when
        # updating as well
        if param_description.options[:action_aware] && param_description.options[:required]
          param_description.required = true
        end
        prepare_hash_params
      end

      def params_ordered
        @params_ordered ||= _moon_raker_dsl_data[:params].map do |args|
          options = args.find { |arg| arg.is_a? Hash }
          options[:parent] = param_description
          MoonRaker::ParamDescription.from_dsl_data(param_description.method_description, args)
        end
      end

      def validate(value)
        return false unless value.is_a? Hash
        if @hash_params
          @hash_params.each do |k, p|
            if MoonRaker.configuration.validate_presence?
              raise ParamMissing.new(p) if p.required && !value.has_key?(k)
            end
            if MoonRaker.configuration.validate_value?
              p.validate(value[k]) if value.key?(k)
            end
          end
        end
        true
      end

      def process_value(value)
        if @hash_params && value
          return @hash_params.each_with_object({}) do |(key, param), api_params|
            if value.key?(key)
              api_params[param.as] = param.process_value(value[key])
            end
          end
        end
      end

      def description
        'Must be a Hash'
      end

      def expected_type
        'hash'
      end

      # where the group definition should be looked up when no scope
      # given. This is expected to return a controller.
      def _default_param_group_scope
        @param_group && @param_group[:scope]
      end

      def merge_with(other_validator)
        if other_validator.is_a? HashValidator
          @params_ordered = ParamDescription.unify(params_ordered + other_validator.params_ordered)
          prepare_hash_params
        else
          super
        end
      end

      def prepare_hash_params
        @hash_params = params_ordered.reduce({}) do |h, param|
          h.update(param.name.to_sym => param)
        end
      end
    end

    # special type of validator: we say that it's not specified
    class UndefValidator < BaseValidator
      def validate(_value)
        true
      end

      def self.build(param_description, argument, _options, _block)
        new(param_description) if argument == :undef
      end

      def description
        nil
      end
    end

    class NumberValidator < BaseValidator
      def validate(value)
        self.class.validate(value)
      end

      def self.build(param_description, argument, _options, _block)
        new(param_description) if argument == :number
      end

      def description
        'Must be a number.'
      end

      def self.validate(value)
        value.to_s =~ /\A(0|[1-9]\d*)\Z$/
      end
    end

    class BooleanValidator < BaseValidator
      def validate(value)
        %w[true false 1 0].include?(value.to_s)
      end

      def self.build(param_description, argument, options, block)
        if argument == :bool || argument == :boolean
          self.new(param_description)
        end
      end

      def expected_type
        'boolean'
      end

      def description
        "Must be 'true' or 'false' or '1' or '0'"
      end
    end

    class NestedValidator < BaseValidator
      def initialize(param_description, argument, param_group)
        super(param_description)
        @validator = MoonRaker::Validator:: HashValidator.new(param_description, argument, param_group)
        @type = argument
      end

      def validate(value)
        value ||= [] # Rails convert empty array to nil
        return false if value.class != Array
        value.each do |child|
          return false unless @validator.validate(child)
        end
        true
      end

      def process_value(value)
        value ||= [] # Rails convert empty array to nil
        @values = []
        value.each do |child|
          @values << @validator.process_value(child)
        end
        @values
      end

      def self.build(param_description, argument, options, block)
        # in Ruby 1.8.x the arity on block without args is -1
        # while in Ruby 1.9+ it is 0
        new(param_description, block, options[:param_group]) if block.is_a?(Proc) && block.arity <= 0 && argument == Array
      end

      def expected_type
        'array'
      end

      def description
        'Must be an Array of nested elements'
      end

      def params_ordered
        @validator.params_ordered
      end
    end
  end
end