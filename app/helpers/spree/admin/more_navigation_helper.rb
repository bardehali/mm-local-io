module Spree::Admin::MoreNavigationHelper
  def admin_breadcrumbs
    @admin_breadcrumbs ||= []
  end

  # Add items to current page breadcrumb heirarchy
  def admin_breadcrumb(*ancestors, &block)
    admin_breadcrumbs.concat(ancestors) if ancestors.present?
    admin_breadcrumbs.push(capture(&block)) if block_given?
  end

  # Render Bootstrap style breadcrumbs
  def render_admin_breadcrumbs
    if content_for?(:page_title)
      admin_breadcrumb(content_for(:page_title))
    end

    content_tag :nav, class:'breadcrumbs' do
      content_tag :ol, class: 'breadcrumb' do
        segments = admin_breadcrumbs.collect do |level|
          content_tag(:li, level, class: "breadcrumb-item #{level == admin_breadcrumbs.last ? 'active' : ''}")
        end
        Spree::Product.logger.info "| segments: #{segments}"
        safe_join(segments)
      end
    end
  end

  ##
  # Avoid need of inline svg always when extension svg not in @name.
  def svg_icon(name:, classes: '', width:, height:)
    if name.ends_with?('.svg')
      icon_name = File.basename(name, File.extname(name))
      inline_svg_tag "backend-#{icon_name}.svg", class: "icon-#{icon_name} #{classes}", size: "#{width}px*#{height}px"
    else
      content_tag(:span, class:'icon icon-move handle ui-sortable-handle') { }
    end
  end

  def admin_page_title
    if content_for?(:title)
      content_for(:title)
    elsif content_for?(:page_title)
      content_for(:page_title)
    elsif admin_breadcrumbs.any?
      admin_breadcrumbs.map{ |x| strip_tags(x) }.reverse.join(' - ')
    else
      t(controller.controller_name, default: controller.controller_name.titleize, scope: 'spree')
    end
  end

=begin
  From Bootstrap, resulting HTML
  <div class="btn-group btn-group-toggle" data-toggle="buttons">
  <label class="btn btn-secondary active">
    <input type="radio" name="options" id="option1" checked> Active
  </label>
  <label class="btn btn-secondary">
    <input type="radio" name="options" id="option2"> Radio
  </label>
  <label class="btn btn-secondary">
    <input type="radio" name="options" id="option3"> Radio
  </label>
=end
  ##
  # You can construct your own link or input w/ yield variables.
  # @yield current value [nil or Boolean], is active [Boolean]
  def group_of_filter_options(param_name, group_html_attributes = {}, option_html_attributes = {}, &block)
    is_filter_all = params[param_name].nil?
    is_filter_true = params[param_name].to_s == 'true'
    is_filter_false = params[param_name].to_s == 'false'
    group_class_attr = group_html_attributes.delete(:class) || ''
    option_class_attr = option_html_attributes.delete(:class) || ''
    content_tag :div, group_html_attributes.merge(class: "#{group_class_attr} filter-options-group btn-group") do
      if block_given?
        concat( yield nil, is_filter_all )
      else
        concat link_to( 'all', { param_name => nil }, option_html_attributes.merge(class:"#{option_class_attr}#{' active' if is_filter_all}", id: "#{param_name}_all") )
      end

      if block_given?
        concat( yield true, is_filter_true )
      else
        concat link_to( "only yes", { param_name => true }, option_html_attributes.merge(class:"#{option_class_attr}#{' active' if is_filter_true}", id: "#{param_name}_true") )
      end

      if block_given?
        concat(yield false, is_filter_false)
      else
        concat link_to( "only no", { param_name => false }, option_html_attributes.merge(class:"#{option_class_attr}#{' active' if is_filter_false}", id: "#{param_name}_false") )
      end
    end
  end

  ##
  # Generate the category's button for selection using @category_link_proc and dropdown of its children.
  #
  def category_taxon_selector(category_taxon, category_link_proc)
    content_tag(:div, class: "categories-level-#{category_taxon.level}") do # card card-body
      concat( content_tag(:div, class:'category-row input-group', id:"category_taxon_row_#{category_taxon.id}") do
        concat category_link_proc.call(category_taxon)
        concat( content_tag(:div, class:'input-group-append') do
          button_tag(' ', type:'button', class:'btn-category dropdown-toggle fa fa-angle-down',
            'data-toggle' => 'collapse', 'data-target' => "#children_categories_#{category_taxon.id}",
            'aria-expanded' => 'false', 'aria-controls'=>'')
        end ) if category_taxon.children.present? # input-group-append
      end ) # input-group

      concat( content_tag(:div, class:"children-categories children-categories-level-#{category_taxon.level} collapse", id: "children_categories_#{category_taxon.id}") do
        children_html = ''
        category_taxon.children.each do|child_cat|
          children_html += category_taxon_selector(child_cat, category_link_proc).html_safe
        end # category_taxon.children.each
        children_html.html_safe
      end )
    end # card
  end

  def spree_navigation_data
    # put top category
  rescue
    []
  end

  ##
  # For the seller, current user, retrieves the counts of orders per state in Spree::Order table.
  # This adds the entries 'all' => sum of all, 
  #   'sales' => counts of 'payment', 'deliver' and 'complete'
  #   'messages' => counts of 'payment' and 'delivery'
  # The current user being admin would be all orders.
  # @return [Hash of symbol to Integer]
  def order_stats
    unless @order_stats
      conds = spree_current_user&.admin? ? nil : { seller_user_id: spree_current_user&.id }
      @order_stats = Spree::Order.where(conds).group('state').count
      @order_stats['all'] = @order_stats.values.sum
      if spree_current_user&.admin?
        @order_stats['messages'] = Spree::Order.complete.joins(:complaint).count("DISTINCT(#{Spree::Order.table_name}.id)")
        @order_stats['paid_need_tracking'] = ::Spree::Order.paid_need_tracking.count("DISTINCT(#{User::Message.table_name}.record_id)")
      elsif spree_current_user
        specific_user_cond = ["#{Spree::Order.table_name}.seller_user_id=?", spree_current_user.id]
        @order_stats['complete'] = Spree::Order.complete.with_provided_tracking_number.where(specific_user_cond).count
        @order_stats['pending'] = Spree::Order.complete.without_complaint_or_tracking_number.where(specific_user_cond).count
      end
      @order_stats['sales'] = @order_stats['messages'].to_i
    end
    @order_stats
  end

  ##
  # 
  def make_download_url(request, extension = 'csv')
    uri = URI(request.url)
    download_url = uri.path.to_s + '.csv'
    download_url += '?' + uri.query.to_s + (uri.query.present? ? '&limit=all' : 'limit=all')
    download_url
  end

  ##
  # Highlight or show link
  # @links [Array of a link]
  #   Each being arguments for link_to call
  #   match_path: '/products', label: is_admin ? t('spree.products') : t('product.my_products')
  def tab_links(links, common_link_options = {})
    current_path = request.path
    links.each do|link_args|
      text = link_args.first
      url = link_args[1]
      if current_path == url
        concat content_tag(:strong, common_link_options) { text }
      else
        concat content_tag(:a, common_link_options.merge(href: url) ) { text }
      end
    end
    ''
  end
end
