module Spree::Admin::MoreProductsHelper
  def description_rows_count
    if @admin_new
      2
    elsif @product.has_variants?
      15
    else
      22
    end
  end

  def status_label(status)
    css_class = 
      case status
        when 'invalid'
          'text-waring'
        when 'pending'
          'text-secondary'
        when 'public'
          'text-success'
        else
          ''
      end
    content_tag(:label, class: css_class){ status }
  end

  ##
  # Compared against variant.options_text, conditional versions depending on siged in user, 
  # such as only admin can see 
  # @options
  #   :present_with_option_type [Boolean] default true; whether to include "Color: Red" or just "Red"
  #   :exclude_option_types_anyway [Boolean] default false; originally only admin sees all 
  #     option_type & value pairs, and users excluded from Spree::OptionType.excluded_ids_from_users.
  def variant_options_text(variant, options = {})
    present_with_option_type = options.fetch(:present_with_option_type) { true }
    exclude_option_types_anyway = options.fetch(:exclude_option_types_anyway) { false }
    excluded_ids_from_users = Spree::OptionType.excluded_ids_from_users
    option_values = (!exclude_option_types_anyway && spree_current_user&.admin?) ? variant.option_values : 
      variant.option_values.to_a.reject{|ov| excluded_ids_from_users.include?(ov.option_type_id) }
    presenter = Spree::Variants::OptionsPresenter.new(variant, option_values)
    present_with_option_type ? presenter.to_sentence : presenter.to_only_option_value_sentence(true)
  end

  ##
  # Determines whether to show "Created by ", instead of always show 
  # ' by admin' or ' by User(302)'.
  def valid_creator?(user)
    return false if user.nil?
    !user.admin? && user.username.present?
  end
end