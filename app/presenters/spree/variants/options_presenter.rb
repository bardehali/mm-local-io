##
# Override of original, to allow alternative way to initialize
# with specific option_values instead of variant.option_values
module Spree
  module Variants
    class OptionsPresenter
      WORDS_CONNECTOR = ', '.freeze

      attr_reader :variant

      ##
      # @variant_or_option_values [either Spree::Variant or Collection of Spree::OptionValue]
      def initialize(variant, option_values = nil)
        @variant = variant
        @option_values = (option_values || variant.option_values ).to_a
        @option_values.reject!(&:one_value?)
      end

      def to_sentence(exclude_one_values = false)
        options = @option_values
        options = sort_options(options)
        if exclude_one_values
          options = options.reject{|op| op.one_value? }
        end
        options = present_options(options)

        join_options(options)
      end

      def to_only_option_value_sentence(exclude_one_values = false)
        options = @option_values
        options = sort_options(options)
        final_options = []
        options.each do|ov|
          next if exclude_one_values && ov.one_value?
          final_options << ov.presentation
        end
        join_options(final_options)
      end

      private

      def sort_options(options)
        options.sort_by { |o| o.option_type.position }
      end

      def present_options(options)
        options.map do |ov|
          method = "present_#{ov.option_type.name}_option"

          respond_to?(method, true) ? send(method, ov) : present_option(ov)
        end
      end

      def present_color_option(option)
        "#{option.option_type.presentation}: #{option.name}"
      end

      def present_option(option)
        "#{option.option_type.presentation}: #{option.presentation}"
      end

      def join_options(options)
        options.to_sentence(words_connector: WORDS_CONNECTOR, two_words_connector: WORDS_CONNECTOR)
      end
    end
  end
end
