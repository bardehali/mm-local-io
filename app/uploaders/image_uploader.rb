class ImageUploader < CarrierWave::Uploader::Base
  # include CarrierWaveDirect::Uploader
  
  # Include RMagick or MiniMagick support:
  include CarrierWave::RMagick
  # include CarrierWave::MiniMagick

  include Rails.application.routes.url_helpers
  include Spree::Core::Engine.routes.url_helpers

  # Choose what kind of storage to use for this uploader:
  # storage :file

  storage :fog

  LOCAL_IMAGE_STORAGE_PATH = ENV['LOCAL_IMAGE_STORAGE_PATH']
  HOSTED_LOCALLY = LOCAL_IMAGE_STORAGE_PATH.present? && Dir.exists?(LOCAL_IMAGE_STORAGE_PATH)

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url(*args)
  #   # For Rails 3.1+ asset pipeline compatibility:
  #   # ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
  #
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end

  # Process files as they are uploaded:
  # process scale: [200, 300]
  #
  # def scale(width, height)
  #   # do something
  # end

  # Create different versions of your uploaded files:
  version :thumb do
    process resize_to_fit: [200, 200]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  # def extension_whitelist
  #   %w(jpg jpeg gif png)
  # end

  #def original_filename
  #end

  def local_file_path(which_version = nil)
    fn = original_filename(which_version)
    File.join(LOCAL_IMAGE_STORAGE_PATH, store_dir, fn)
  end

  ##
  # Instead of AWS encrypted or assigned image key, this is 
  # an encoded form of concatenated model attribute values.
  # So can be used as public mask of image filename instead of original_filename.
  def image_id
    s = ''
    [:user_id, :send_user_id, :recipient_user_id, :id].each do|a|
      s << model.send(a).to_s if model.respond_to?(a)
    end
    s.to_i.to_s(32)
  end

  ##
  # Based on 'url'.  If nil, would be 'jpg'
  def extension
    which_url = url
    which_url ||= 'image.jpg' # removed or lost image would be nil
    which_url.split('?').first.split('.').last
  end

  # Public encrypted filename instead of original filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  def public_filename
    # "something.jpg" if original_filename
    image_id + '.' + extension
  end

  def public_url(which_version = nil)
    r = model
    if r.is_a?(User::Message)
      if which_version == :thumb
        # _path call not absolute here
        # user_message_thumb_path(id: r.id, filename: public_filename )
        "/messages/#{r.id}/thumb/#{public_filename}"
      else
        "/messages/#{r.id}/image/#{public_filename}"
      end
    else
      which_version ? url(which_version) : url
    end
  end

  def model_id_folder_deliminated
    model.id.to_s.split(/(.{3})/).reject(&:blank?).join('/')
  end
end
