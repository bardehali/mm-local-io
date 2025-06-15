##
# Extension of user-related helper methods.
module Spree
  module MoreUsersHelper

    ##
    # Possible modified version of Spree::Address.required_fields.
    def updated_address_required_fields
      @address_required_fields ||= Spree::Address.required_fields
      @address_required_fields.reject!{|f| f == :phone } unless Spree::Config[:address_requires_phone]
      @address_required_fields
    end

    ##
    # Because of problem overriding Spree::Address.required_fields to remove not required phone,
    # this is modified copy of that in Spree::AddressesHelper.
    def updated_address_field(form, method, address_id = 'b', &handler)
      content_tag :p, id: [address_id, method].join, class: 'form-group checkout-content-inner-field has-float-label' do
        if handler
          yield
        else
          is_required = updated_address_required_fields.include?(method)
          method_name = I18n.t("activerecord.attributes.spree/address.#{method}")
          required = Spree.t(:required)
          form.text_field(method,
                          class: [is_required ? 'required' : nil, 'spree-flat-input'].compact,
                          required: is_required,
                          placeholder: is_required ? "#{method_name} #{required}" : method_name,
                          aria: { label: method_name })
        end
      end
    end

    def get_default_address
      default_country = if spree_current_user&.country_code
                          Spree::Country.find_by(iso: spree_current_user.country_code)
                        else
                          Spree::Country.default
                        end

      default_address = Spree::Address.new(country: default_country)
      default_address.state = default_country.states.first if default_country&.states&.any?
      default_address
    end

    def timeline_table(&block)
      timeline = TimelineInSteps.new
      yield timeline
      content_tag :table, class:'w-100', style:"margin-left: -#{100.0 / timeline.steps.size / 2}%;" do
        content_tag :tbody do
          content_tag :tr do
            # Spree::User.logger.debug "| timeline.steps #{timeline.steps}"
            step_index = 0
            step_rows = timeline.steps.collect do|step_h|
              step_index += 1
              # First cell would have empty left side of number 1.
              content_tag(:td, class:"timeline-item#{' highlighted' if step_h[:highlighted] }", style:"width: #{100.0 / timeline.steps.size}%;") do
                td_s = content_tag(:div, class:'row timeline-number') do
                  number_parts = []
                  if (step_index > 1)
                    number_parts << content_tag(:span, class:'middle-bar-from-start-abs') { '' }.html_safe
                  end
                  number_parts << content_tag(:span, class:"number-badge") do
                    step_h[:badge_text].to_s
                  end.html_safe
                  if (step_index < timeline.steps.size)
                    number_parts << content_tag(:span, class:'middle-bar-to-end-abs') { '' }.html_safe
                  end
                  # Spree::User.logger.debug "  | TD #{number_parts}"
                  number_parts.join("\n").html_safe
                end
                if step_h[:bottom_label].present?
                  td_s << content_tag(:div, class:'text-center') do
                    content_tag(:h6) { step_h[:bottom_label] }
                  end
                end
                td_s
              end # td
            end
            # Spree::User.logger.debug "| step_rows: #{step_rows}"
            safe_join(step_rows, "\n")
          end
        end
      end
    end


    ##
    # @return [Array of Hash, w/ keys 'seller', 'message']
    def fetch_happy_seller_messages(limit = 5)
      list = YAML::load_file( File.join(Rails.root,'data/sample_happy_seller_messages.yml') )
      indices = []
      0.upto(list.size - 1){|i| indices << i; }
      indices.shuffle!
      indices[0,limit].collect{|i| list[i] }
    end

    def fetch_happy_buyer_messages(limit = 10)
      list = YAML::load_file( File.join(Rails.root,'data/happy_buyer_messages.yml') )
      indices = []
      0.upto(list.size - 1){|i| indices << i; }
      indices.shuffle!
      indices[0,limit].collect{|i| list[i] }
    end

    def fetch_random_happy_buyer_message(limit = 1)
      list = YAML::load_file( File.join(Rails.root,'data/happy_buyer_messages.yml') )
      indices = []
      0.upto(list.size - 1){|i| indices << i; }
      indices.shuffle!
      indices[0,limit].collect{|i| list[i] }
    end

  end
end
