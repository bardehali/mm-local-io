module Retail::SitesHelper
  def select_options_of_retail_sites(selected = nil)
    options = [ ['', ''] ]
    Retail::Site.all.each do|retail_site|
      options << [retail_site.name, retail_site.id]
    end
    options_for_select(options, selected || params[:retail_site_id])
  end
end
