require 'csv'
require File.join(Rails.root, 'lib/tasks/task_helper')
include ::TaskHelper

namespace :categories do
  ##
  # Imports retail site's categories to iOffer category taxons
  # Required arguments:
  #   1. CSV file
  # Syntax like: RETAIL_SITE=zalando bundle exec rake products:import_from_csv "~/site_categories.csv"
  # CSV file columns
  #   category name
  #   ioffer category taxon ID
  # Required environment variables:
  #   RETAIL_SITE [name of retail site]
  task :import_from_csv => [:environment] do
    retail_site_name = ENV['RETAIL_SITE']
    if retail_site_name.blank?
      puts "RETAIL_SITE is required"
      exit! 
    end

    ARGV.shift
    csv_file = ARGV.shift
    puts "#{Time.now.to_s} ========================================="
    puts "CSV file: #{csv_file}"
    retail_site = Retail::Site.find_or_create_by_name(retail_site_name.strip)
    root = retail_site.fetch_root_site_category

    puts "retail site: #{retail_site.name} (#{retail_site.id})"

    NAME = 0
    TAXON_ID = 1

    CSV.parse(File.read(csv_file), headers: false).each_with_index do |csv_row, row_index|
      begin
        name = csv_row[NAME].strip
        next if row_index == 0 && name =~ /\A(category\s+)name\Z/i
        scat = Retail::SiteCategory.find_or_create_by(retail_site_id: retail_site.id, name: name ) do|_scat|
            _scat.site_name ||= retail_site.name
          end
        if scat.parent_id != root.id
          scat.move_to_child_of(root)
        end
        taxon_category = Spree::Taxon.find_by(id: csv_row[TAXON_ID] )
        taxon_category ||= Spree::Taxonomy.categories_taxonomy.taxons.where(name: name).last
        puts '%30s | %5d (%s)' % [name, csv_row[TAXON_ID], taxon_category&.breadcrumb]
        scat.update(mapped_taxon_id: taxon_category.id) if taxon_category
      rescue Exception => row_e
        puts "** Problem w/ row #{row_index}: #{row_e}"
      end
    end
  end
end