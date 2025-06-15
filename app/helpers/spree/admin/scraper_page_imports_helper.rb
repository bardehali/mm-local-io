module Spree::Admin::ScraperPageImportsHelper
  def load_import_runs
    unless @import_runs
      import_run_ids = collection.collect{|import| import.page.import_page_entries.collect(&:scraper_import_run_id)  }.flatten.uniq
      @import_runs = ::Scraper::ImportRun.where(id: import_run_ids).all
    end
    @import_runs
  end

  def build_keywords_regexpressions
    unless @keywords_regexpressions
      @keywords_regexpressions = []
      keywords = Set.new
      load_import_runs.each do|import_run|
        if import_run.keywords.present?
          # normalized_kw = import_run.keywords.gsub(/([^\w\s\-\?\|]+)/, '').gsub(/(\s+)/, '\s+').gsub('-','[\s\-]')
          normalized_kw = import_run.keywords.gsub(/([^\w\s\-\?\|]+)/, ' ').gsub('-','[\s\-]')
          @keywords_regexpressions << /\b(#{normalized_kw})/i
        end
      end
    end
    @keywords_regexpressions
  end

  def highlight_keywords(s, wrapping_tag = 'span')
    copy = s.clone
    build_keywords_regexpressions.each do|r|
      #while (m = r.match(copy) )
      #  copy.gsub!(m[1], "<#{wrapping_tag} class='text-highlight'>#{$1}</#{wrapping_tag}>")
      #end
      copy.gsub!(r, "<#{wrapping_tag} class='text-highlight'>"+ '\1' +"</#{wrapping_tag}>")
    end
    copy.html_safe
  end
end