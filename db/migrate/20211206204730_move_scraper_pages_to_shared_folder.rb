class MoveScraperPagesToSharedFolder < ActiveRecord::Migration[6.0]
  def change
    spages_folder = "spages_#{Rails.env}"
    old_path = File.join(Rails.root, "public/#{spages_folder}")
    puts "Look for old path: #{old_path}"
    if Dir.exist?(old_path)
      FileUtils.mv( old_path, File.join(Rails.root, "public/spree/") )
    end
    Scraper::Page.where("file_path LIKE '%/public/#{spages_folder}/%'").each do|page|
      page.update(file_path: page.file_path.sub("/public/#{spages_folder}", "/public/spree/#{spages_folder}") )
    end
  end
end
