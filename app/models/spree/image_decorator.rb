module Spree::ImageDecorator
  extend ActiveSupport::Concern

  def self.prepended(base)
    base.extend ClassMethods
    base.const_set 'IMAGE_EXTENSION_REGEXP', /\.(jpe?g|png|gif)\Z/i
    base.const_set 'IMAGE_DATA_REGEXP', /\Adata:(image\/([\w]{2,}));base64,/
    base.const_set 'IMAGE_VERSIONS_ON_CDN', Set.new( [:plp_and_carousel, :product, :plp_and_carousel_lg, :plp_and_carousel_md, :pdp_thumbnail, :zoomed, :small, :large, :mini] )

    base.scope :joins_with_variant, -> { joins("inner join `#{Spree::Variant.table_name}` on `#{Spree::Variant.table_name}`.id=viewable_id and viewable_type='Spree::Variant'") }

    base.attr_accessor :image_data, :content_type, :original_filename
    base.after_save :update_data_for_viewable!
    base.after_destroy :update_data_for_viewable!
    base.after_create :schedule_to_check_attachment
  end

  module ClassMethods
    def accessible_by(ability, action)
      if ability.public_action?(action)
        self.where(nil)
      else
        # this needs to check viewable(variant).product.user_id
        self.joins("inner join `#{Spree::Variant.table_name}` on `#{Spree::Variant.table_name}`.id=viewable_id and viewable_type='Spree::Variant' join `#{Spree::Product.table_name}` on `#{Spree::Variant.table_name}`.product_id=`#{Spree::Product.table_name}`.id").where("`#{Spree::Product.table_name}`.user_id = ?", ability.user.id ).count
      end
    end

    ##
    # @viewable <some ActiveRecord::Base>
    def make_params_from_file(viewable, image_path)
      image_name = image_path.split('/').last
      extension = image_name.match(IMAGE_EXTENSION_REGEXP).try(:[], 1)
      unless extension
        extension ||= '.jpeg'
        image_name += extension
      end
      content_type = extension.gsub(/\A(\.)/, 'image/')
      uploaded_file = ActionDispatch::Http::UploadedFile.new(
        filename: image_name, content_type: content_type, tempfile: File.open(image_path) )
      { viewable_type: viewable.class.to_s, viewable_id: viewable.id,
        attachment_content_type: content_type, attachment_file_name: image_name,
        attachment: uploaded_file}
    end

    ##
    # Check if slug is available, else would use viewable.id.
    # @image_path_or_content_type [String] can be file path or content_type like "image/jpeg"
    # @return [String] either "slug.1.jpg" or "3209.1.jpg" or "product-3209.1.jpg"
    def make_related_file_name(viewable, image_path_or_content_type, index = nil, prepend_class_if_id_only = false)
      image_name = image_path_or_content_type.split('/').last
      extension = image_name.split(/[.\/]/).last # content_type would not have .jpg cuz only left w/ jpg
      ending = "#{'.' + index.to_s if index}.#{extension}"
      if viewable.respond_to?(:slug)
        viewable.slug + ending
      else
        "#{viewable.class.to_s.split(':').last.downcase +'-' if prepend_class_if_id_only}#{viewable.id}#{ending}"
      end
    end

    # Same as that specified for "has_attached_file"
    def make_file_path(viewable, file_name)
      File.join(Rails.root, "public/spree/products/#{viewable.id}/original/#{file_name}" )
    end
  end

  def attach_with_old_filepath!
    return nil if old_filepath.blank?
    self.attachment.attach(io: File.open(old_filepath), filename: filename)
  rescue Errno::ENOENT => file_e
    logger.warn "** Problem using Spree::Image(#{id}).#{self}: #{file_e}"
    return nil
  end

  # Check for missing local files of ActiveStorage files.  Download and save
  # if needed.
  def ensure_attachment_file_saved!
    local = ActiveStorage::Blob.service.path_for(attachment.key)
    unless ActiveStorage::Blob.service.exist?(attachment.key)
      #FileUtils.mkdir_p( File.dirname(local) ) if defined?(ActiveStorage::Service::DiskService) && ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::DiskService)
      # File.open(local,'wb+'){|f| f.write attachment.download }
      download = attachment.download
      if download.present?
        img.attachment.attach(io: StringIO.new(download), filename: img.attachment.filename.to_s )
      end
      if attachment.reload.download.blank?
        if File.exists?(local)
          self.attachment.attach(io: File.open(local), filename: attachment.filename.to_s )
        elsif old_filepath.present? && File.exists?(old_filepath)
          self.attachment.attach(io: File.open(old_filepath), filename: attachment.filename.to_s )
        end
      end
    end
    local
  end

  def schedule_to_check_attachment
    # Better be delayed because of delay to file/cloud storage.
    logger.debug "|image> scheduling to ensuring attachment"
    self.delay(queue: 'ITEM_IMAGE', priority: 10).ensure_attachment_variants_processed!
  end

  ##
  ##
  # Possible variants would not be processed.  Best to delay this to background run.
  def ensure_attachment_variants_processed!
    Spree::Image::IMAGE_VERSIONS_ON_CDN.each do|vname|
      vsize = self.class.styles[vname]
      self.attachment.variant(resize: vsize).processed
      logger.debug "|image> ensuring attachment #{vsize}"
    end
  rescue Exception => e
    logger.warn "|image> ** Image Not Processed #{self}: #{e}\n" + e.backtrace.join("\n")
  end

  def preset_attributes
    if viewable
      self.viewable_id = viewable.id
      self.viewable_id ||= viewable.master.try(:id) if viewable.respond_to?(:master)
      self.viewable_type = viewable.class.to_s
    end
    self.content_type = attachment.content_type if attachment && attachment.respond_to?(:content_type)
  end

  def decode_base64_image
    if image_data.present? && image_data =~ Spree::Image::IMAGE_DATA_REGEXP
      self.attachment_content_type ||= $1
      image_data.gsub!(Spree::Image::IMAGE_DATA_REGEXP,'')

      self.filename ||= self.class.make_related_file_name(viewable, attachment_content_type, position) if viewable
      self.attachment_file_name ||= filename

      if attachment_content_type && filename.present?
        self.attachment = { io: StringIO.new(Base64.decode64(image_data) ), filename: filename, content_type: attachment_content_type }
      end
    end
  end

  def update_data_for_viewable!
    if viewable.is_a?(Spree::Variant) && attachment
      viewable.product.recalculate_status!
    end
  rescue Exception => data_e
    logger.warn "| Image(#{id}) w/ for viewable #{viewable_id} w/ attachment #{attachment}\n#{data_e}"
  end
end

::Spree::Image.prepend Spree::ImageDecorator if ::Spree::Image.included_modules.exclude?(Spree::ImageDecorator)
