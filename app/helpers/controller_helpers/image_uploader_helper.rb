##
# For controller to use ImageUploader
module ControllerHelpers::ImageUploaderHelper

  ##
  # @image [ImageUploader]
  def render_image(image, which_version = nil)
    if image && image.image_id == params[:filename] # extension not counted
      if ::ImageUploader::HOSTED_LOCALLY && File.exists?(image.local_file_path)
        File.open( image.local_file_path(which_version) ) do |img|
          send_data img.read, type: image.content_type, disposition: 'inline'
        end
      else # remote
        remote_url = which_version ? image.url(which_version) : image.url
        logger.debug "GET #{which_version} #{remote_url}"
        open(remote_url) do |img|
          send_data img.read, type: img.content_type || 'image/jpeg', disposition: 'inline'
        end
      end
    else
      render file:'public/404.html', status: :not_found
    end
  end
end