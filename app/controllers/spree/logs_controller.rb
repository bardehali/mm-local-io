module Spree
  class LogsController < Spree::BaseController
    # No CSRF protection needed since it's a simple GET request
    protect_from_forgery with: :null_session

    def share_click
      # Just return 200 OK without logging or processing
      head :ok
    end
  end
end
