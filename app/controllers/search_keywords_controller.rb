class SearchKeywordsController < ApplicationController
  
  def index
    clean_kw = SearchKeyword.clean_chars(params[:keywords])
    if clean_kw.present?
      @search_keywords = 
        if params[:searcher] != 'db'
          search = SearchKeyword.make_search(clean_kw)
          SearchKeyword.logger.debug "| SearchKeyword: #{search.search.definition}"
          search.results
        else
          SearchKeyword.where("keywords LIKE '%#{clean_kw}%'").limit(10).order('search_count desc')
        end
    else
      @search_keywords = []
    end

    respond_to do|format|
      format.json { @search_keywords.collect(&:as_json) }
      format.js
    end
  end


end