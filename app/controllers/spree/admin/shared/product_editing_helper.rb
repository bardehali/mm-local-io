##
# For controller that has polymorphic relationship like /products/:product_id/images,
# so @product is need for loading
module Spree::Admin::Shared::ProductEditingHelper

  # Ploymorphic fix supposedly, but not working :(
  #def self.prepended(base)
  #  base.load_resource :product, parent: true
  #  base.load_and_authorize_resource :images, through: :product
  #end

  # Overriding.  Authorize against product
  # Polymorphic authorization problem hard to resolve.
  def authorize_admin
    # logger.debug "| ProductEditingHelper#authorize_admin of user #{try_spree_current_user&.to_s}"
    @product ||= ::Spree::Product.friendly.find(params[:product_id]) if params[:product_id]

    if @product
      record = @product
    elsif respond_to?(:model_class, true) && model_class
      record = model_class
    else
      record = Object
    end

    if @product || member_action?
      authorize! action, record
    end
  end

  ##
  # @uploaded_images [Array of parameter hash w/ Spree::Asset properties]
  def save_uploaded_images(uploaded_images = nil)
    uploaded_images = uploaded_images || params[:product].try(:[], :uploaded_images).to_a
    logger.info "-> Save uploaded_images: #{@uploaded_images}"
    @product.uploaded_images = uploaded_images
    @product.updated_at = Time.now # enforce after calls
    @product.save

  end

end  