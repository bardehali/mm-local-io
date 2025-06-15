module Spree::Admin::RecordReviewsHelper
  def default_status?(record)
    review = record.record_review
    review.nil? ? true :
      (review.new_curation_score.nil? ||
        review.new_curation_score == record.class::INITIAL_CURATION_SCORE ||
        review.iqs == record.class::DEFAULT_IQS)
  end

  ##
  # @record_or_string [String or Spree::Product or whichever object that has record_review]
  def status_css_class(record_or_string)
    css_name = nil
    if record_or_string.is_a?(String)
      css_name = record_or_string.downcase.gsub(/(\s+)/, '-')
    elsif record_or_string.record_review
      css_name = record_or_string.record_review.status_name.downcase.gsub(/(\s+)/, '-')
    end
    css_name || 'default-status'
  end

  STATUS_NAME_TO_CSS_CLASS_OR_IMAGE = {
      'default-status' => '',
      'good-image' => 'icon/star-gold-border.png',
      'bad-main-image' => 'icon/bad-image-blue.png',
      'custom-watermarks' => 'icon/custom-watermarks.png',
      'prohibited' => 'icon/prohibited-red-large.png',
      'catalog-listing' => 'fa-border-all',
      'keyword-spam' => 'icon/keyword-spam.png',
      'contact-info' => 'icon/contact.png',
      'listing-violation' => 'icon/listing-violation.png'}
  STATUS_NAME_TO_MENU_ITEM_CLASS_OR_IMAGE = {
      'default-status' => '',
      'good-image' => 'icon/star-gold-border.png',
      'bad-main-image' => 'icon/bad-image-black.png',
      'custom-watermarks' => 'icon/custom-watermarks-red-small.png',
      'prohibited' => 'icon/prohibited-red-small.png',
      'catalog-listing' => 'fa-border-all',
      'keyword-spam' => 'icon/keyword-spam.png',
      'contact-info' => 'icon/contact.png',
      'listing-violation' => 'icon/listing-violation.png'}

  IMAGE_ENDING_REGEXP = /\.(jpe?g|gif|png)\Z/i

  def status_icon(record)
    v = STATUS_NAME_TO_CSS_CLASS_OR_IMAGE[ status_css_class(record) ]
    more_css_class = nil
    if v && v.match(IMAGE_ENDING_REGEXP).nil?
      more_css_class = v
    end
    content_tag(:a, href: '#', class:"glyphicon #{more_css_class}") do
      if v && v =~ IMAGE_ENDING_REGEXP
        image_tag(v) {}
      else
        ' '
      end
    end
  end

  def menu_item_status_icon(record, html_options = {})
    v = STATUS_NAME_TO_MENU_ITEM_CLASS_OR_IMAGE[ status_css_class(record) ]
    more_css_class = html_options[:class] || ''
    if v && v.match(IMAGE_ENDING_REGEXP).nil?
      more_css_class << ' ' + v
    end
    content_tag(:a, href: '#', class:"glyphicon #{more_css_class}") do
      if v && v =~ IMAGE_ENDING_REGEXP
        image_tag(v) {}
      else
        ' '
      end
    end
  end

  ##
  # The stats are those of current database, not those of old iOffer.
  # @out_of_all_user_ids [Array of Integer] provide this to query entire set of user data ahead, 
  #   store and fetch later.  This optimizes multiple queries instead of individual calls.
  # @return [Hash] keys: :all_gross_sales, :all_sales_count, :month_gross_sales, :total_images_count
  def seller_stats(seller_user_id, out_of_all_user_ids = nil)
    this_user_stats = nil
    if out_of_all_user_ids
      unless @all_gross_sales # && @all_sales_counts && @month_gross_sales && @total_images_counts
        gross_sales_query = Spree::Order.where(seller_user_id: out_of_all_user_ids).complete.group('seller_user_id')
        @all_gross_sales = gross_sales_query.sum(:item_total)
        @all_sales_counts = gross_sales_query.count
        @month_gross_sales = gross_sales_query.where('created_at > ?', 30.days.ago).sum(:item_total)
      end
      this_user_stats = {
        all_gross_sales: @all_gross_sales[seller_user_id] || 0.0,
        all_sales_count: @all_sales_counts[seller_user_id] || 0,
        month_gross_sales: @month_gross_sales[seller_user_id] || 0.0
      }
    else
      gross_sales_query = Spree::Order.where(user_id: seller_user_id).complete
      this_user_stats = {
        all_gross_sales: gross_sales_query.sum(:item_total),
        all_sales_count: gross_sales_query.count,
        month_gross_sales: gross_sales_query.where('created_at > ?', 30.days.ago).sum(:item_total)
      }
    end
    this_user_stats
  end

  def revert_record_review_url(record, link_options = {})
    admin_record_reviews_path(link_options.merge( record_review:{ record_type: record.class.to_s, record_id: record.id,
                                              status_code: 0}) )
  end

  def update_link_params(record, status_name, initial_record_review_params = {})
    view = params.delete(:view) || 'list'
    name = status_name.index('-').to_i > 0 ? status_name.titleize : status_name
    { view: view, version: params[:version],
      record_review: initial_record_review_params.merge(
        record_type: record.class.to_s, record_id: record.id,
        status_code: ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING[name] ) 
    }
  end

  def update_record_review_link(record, status_name, link_options = {}, &block)
    name = status_name.index('-').to_i > 0 ? status_name.titleize : status_name
    link_to( admin_record_reviews_path(update_link_params(record, status_name) ),
        link_options.merge(method:'post', remote: true), &block ).html_safe
  end

  def record_review_with_curation_score_link(record, curation_score, link_options = {}, &block)
    link_to( admin_record_reviews_path(update_link_params(record, 'Default', new_curation_score: curation_score) ),
        link_options.merge(method:'post', remote: true), &block ).html_safe
  end
  alias_method :record_review_with_iqs_link, :record_review_with_curation_score_link

  def highlight_text_according_to(text, regexp = nil, replacement_pattern = nil)
    regexp ||= Regexp.union( Filter::BadWord.regexp, Filter::ContactInfo.regexp )
    replacement_pattern ||= '<b>\1\2</b>'
    text.gsub(regexp, replacement_pattern)
  end
end