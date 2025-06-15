module ::Spree::Admin::ImagesControllerDecorator

  def self.prepended(base)
    base.include Spree::Admin::Shared::ProductEditingHelper
    base.helper Spree::Admin::MoreImagesHelper

    base.skip_before_action :authorize_admin, only: [:delete_image]
  end

  def mark_as_main
    @image = Spree::Image.find_by_id(params[:id])
    if @image
      other_images = Spree::Image.where(viewable_type: @image.viewable_type, viewable_id: @image.viewable_id).
        where('id != ?', @image.id)
      ActiveRecord::Base.transaction do
        other_images.update_all('position=position+1')
        @image.set_list_position(1)
      end
    end
  end

  ##
  # Batch upload
  def upload_images
    params.require(:product).permit! # (:uploaded_images)

    save_uploaded_images( params[:product][:uploaded_images].to_a )

    respond_to do|format|
      format.html { redirect_to admin_product_images_path(t: Time.now.to_i) }
    end
  end

  def delete_image
    if @image && can?(:destroy, @image)
      @image.destroy 
    end
    respond_to do|format|
      format.js
    end
  end


  protected

  def object_name
    'image'
  end

  def collection_actions
    super + [:upload_images]
  end

  def permitted_resource_params
    params.require(object_name).permit!
  end

  # Before call by spree
  def build_resource
    record = super
    record.attributes = permitted_resource_params
    record.decode_base64_image
    record
  end

  def collection_url(options = {})
    admin_product_images_path(@product)
  end

  private

  # super is a private method
  def load_edit_data
    @product = ::Spree::Product.friendly.includes(*variant_edit_includes).find(params[:product_id])
    variants = @product.variants_without_order.where(converted_to_variant_adoption: false).
      includes(option_values:[:option_type], images:[:viewable] )
    @variants = variants.where("user_id IS NULL OR user_id=?", spree_current_user.try(:id)).map do |variant|
      [variant.sku_and_options_text, variant.id]
    end
    @variants.insert(0, [Spree.t(:all), @product.master.id]) if spree_current_user.try(:id) == @product.user_id || spree_current_user.try(:admin?)
    logger.info "| variants: #{@variants}"
  end
end

::Spree::Admin::ImagesController.prepend Spree::Admin::ImagesControllerDecorator if ::Spree::Admin::ImagesController.included_modules.exclude?(Spree::Admin::ImagesControllerDecorator)