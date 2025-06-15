class Ioffer::ItemsController < ::ApplicationController

  def index
    PageLog.record_request(request)
    render 'home/index'
  end

  def show
    PageLog.record_request(request)
    render 'home/index'
  end
end
