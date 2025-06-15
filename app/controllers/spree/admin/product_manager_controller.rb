require 'admin/server'
require 'admin/servers/manager'

module Spree
  module Admin
    class ProductManagerController < Spree::Admin::BaseController

      before_action :authorize_real_admin

      def index
        @page_title = 'Product Manager > Takedown'
      end

      def preview_takedown
        @page_title = 'Product Manager > Preview Takedown'
        params.permit(:products_list)
        
        @variant_ids = parse_variant_ids( params[:products_list], 'v' )
        logger.debug "| @variant_ids: #{@variant_ids}"
        @variants = Spree::Variant.with_deleted.where(id: @variant_ids).includes(:product).all

        @variant_adoption_ids = parse_variant_adoption_codes( params[:products_list], 'vp' )
        logger.debug "| @variant_adoption_ids: #{@variant_adoption_ids}"
        @variant_adoptions = Spree::VariantAdoption.with_deleted.where(code: @variant_adoption_ids).includes(variant: [:product]).all

        if @variants.blank? && @variant_adoptions.blank?
          flash[:error] = 'Could not find any products'
          render 'spree/admin/product_manager/index'
        else
          render 'spree/admin/product_manager/preview_takedown'
        end
      end


      def takedown
        params.permit(:variant_ids, :variant_adoption_ids)
        @variants = Spree::Variant.with_deleted.where(id: params[:variant_ids]).includes(:product).all
        @variants.each do|variant|
          variant.takedown!
        end

        @variant_adoptions = Spree::VariantAdoption.where(id: params[:variant_adoption_ids]).includes(variant: [:product] ).all
        @variant_adoptions.each do|variant_adoption|
          variant_adoption.takedown!
        end

        redirect_to admin_product_manager_path(t: Time.now.to_i, variant_ids: @variants.collect(&:id), variant_adoption_ids: @variant_adoptions.collect(&:id) )
      end

      protected

      ##
      # @prefix [String] being either 'vp' (Spree::VariantAdoption) or 'v' (Spree::Variant)
      def parse_variant_ids(text, prefix)
        s = text.to_s.gsub(/(["'])/i, '')
        rows = text.split(/([,\s]+)/i)
        variant_ids = rows.collect do|row|
          /\/#{prefix}\/([\-\w]+\-)?(\d+)/ =~ row ? $2.to_i : nil
        end.compact
      end

      def parse_variant_adoption_codes(text, prefix)
        s = text.to_s.gsub(/(["'])/i, '')
        rows = text.split(/([,\s]+)/i)
        variant_ids = rows.collect do|row|
          /\/#{prefix}\/([\-\w]+\-)?(\w+)/ =~ row ? $2 : nil
        end.compact
      end
    end
  end
end