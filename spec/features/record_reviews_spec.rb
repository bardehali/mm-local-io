require 'rails_helper'
require 'shared/session_helper'
require 'shared/products_spec_helper'
require 'shared/users_spec_helper'

include SessionHelper
include ProductsSpecHelper
include UsersSpecHelper

RSpec.describe ::Spree::RecordReview do
  before(:all) do
    cleanup_spree_products
    setup_all_for_posting_products
    Capybara.ignore_hidden_elements = false
    ::Spree::User.delete_all
    ::Spree::Product.es.rebuild_index!
  end

  after(:all) do
    cleanup_spree_products
  end

  ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING.keys.each_with_index do|name, key_index|
    it "Create RecordReview type #{name} -----------------" do
      check_against(name, ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING.keys[key_index + 1] ) unless name =~ /default/i
    end
  end

  it 'Check Update Page on NIIR' do
    products = populate_sample_products(15, iqs: Spree::Product::DEFAULT_IQS )
    expect(products.all?(&:indexable?) ).to be_truthy
    products = Spree::Product.where(id: products.collect(&:id))
    initial_iqs = products.first.iqs
    expect( products.collect(&:iqs).uniq ).to eq( [Spree::Product::DEFAULT_IQS] )

    puts 'Rest to let search index catch up'
    sleep(5)

    search = Spree::Product.es.search(query:{ terms:{ _id:products.collect(&:id) } }).limit(30)
    result_ids = search.records.collect{|p| p.id.to_i }.sort
    puts "Result IDs: #{result_ids}"

    expect(result_ids).to eq( products.collect(&:id).sort )

    login_admin

    begin
      put admin_batch_update_products_path(format:'js', product_ids: [products.collect(&:id)], iqs: 25, commit:'Update All' )
      Spree::Product.es.rebuild_index!

      products2 = Spree::Product.where(id: products.collect(&:id) )
      expect( products2.collect(&:iqs).uniq ).to eq( [25] )

      puts 'Rest to let search index catch up'
      sleep(5)

      expect( Spree::Product.search(nil, iqs: 20).total_count ).to eq 0
      expect( Spree::Product.search(nil, iqs: 25).total_count ).to eq products.size
    rescue Elasticsearch::Transport::Transport::Errors::NotFound
      # nothing can do w/o index; could happen in test env
    end
  end

  it 'Rate Products on NIIR' do
    products = populate_sample_products(15, iqs: 0 )
    expect(products.none?(&:indexable?) ).to be_truthy

    login_admin

    # Old exact IQS
    # post admin_record_reviews_path(format:'js', record_review: { record_type: product.class.to_s, record_id: product.id, status_code: status_code }  )
    # Parameters: {"record_review"=>{"record_id"=>"1287", "record_type"=>"Spree::Product", "status_code"=>"55"}, "version"=>"old", "view"=>"list"}
  end

  private

  def check_against(record_review_status_name, second_record_review_status_name = nil)

    seller = signup_sample_user(:basic_user) # create(:basic_user, password:'test4444')

    product = find_or_create(:basic_product, :name)
    expect(product).not_to be_nil
    product.user_id = seller.id
    product.save
    expect(product.curation_score).to eq(Spree::Product::INITIAL_CURATION_SCORE)

    status_code = ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING[record_review_status_name]
    expect(status_code).not_to be_nil
    first_is_indexable = product.indexable?
    puts '-' * 60
    puts "Creating review for product #{product.name} => #{record_review_status_name} | status_code, #{status_code}, IQS #{product.iqs} | indexable? #{first_is_indexable}"

    old_curation_score = product.curation_score
    # review = ::Spree::RecordReview.create(record_type: product.class.to_s, record_id: product.id, status_code: status_code)

    login_admin

    post admin_record_reviews_path(format:'js', 
      record_review: { record_type: product.class.to_s, record_id: product.id,
        status_code: status_code }  )
    review = ::Spree::RecordReview.for_record(product).last

    expect(review).not_to be_nil
    expect(review.status_code.to_i).to eq(status_code)
    expect(review.previous_curation_score).to eq(old_curation_score)
    expect(review.new_curation_score.to_i).to eq(review.target_curation_score.to_i)
    product.reload
    expect(product.curation_score.to_i).to eq(review.target_curation_score.to_i)

    if (second_score = ::Spree::RecordReview::NAME_TO_STATUS_CODE_MAPPING[second_record_review_status_name] )
      begin
        post admin_record_reviews_path(format:'js', record_review: { record_type: product.class.to_s, record_id: product.id,
        status_code: second_score }  )

        second_review = ::Spree::RecordReview.for_record(product).last
        expect(second_review.id).to eq(review.id)

        expect(second_review.status_code.to_i).to eq(second_score)
        expect(second_review.previous_curation_score.to_i).to eq(old_curation_score.to_i)
        expect(second_review.new_curation_score.to_i).to eq(second_review.target_curation_score.to_i)

        product.reload
        puts "  2nd status_name #{second_record_review_status_name} => #{second_score} | status_code, #{product.status_code}, IQS #{product.iqs}"
        if first_is_indexable
          if product.iqs.to_i == 0
            puts "  product should turn to not-indexable .. "
            expect(product.indexable?).not_to be_truthy
          end
        else
          if product.iqs.to_i > 0
            puts "  product should turn to indexable .. "
            expect(product.indexable?).to be_truthy
          end
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        # nothing can do w/o index; could happen in test env
      end
      
      product.reload

      # Abandoned update of curation_score as IQS has taken over
    end
  end

  ##
  # Careful giving @count and searching because queries have defined limit per page.
  def populate_sample_products(count = 15, other_product_attributes = {})
    seller = signup_sample_user(:basic_user)
    list = []
    1.upto(count) do|index|
      product_h = attributes_for(:basic_product)
      product_h.merge!(other_product_attributes) if other_product_attributes&.size > 0
      product_h.merge!(available_on: 1.minute.ago, sku: "#{product_h[:sku]}-#{index}", name: product_h[:name] + " - #{index}")
      p = Spree::Product.new(product_h)
      if p.save
        list << p
        # p.master.images.create( attributes_for(:local_image_file) )
        p.touch
      end
    end
    list
  end

  def login_admin

    visit logout_path
    admin_user = find_or_create(:admin_user, :username, password:'test3333')
    expect(admin_user).not_to be_nil
    expect(admin_user.admin?).to be_truthy

    sign_in_from_form(admin_user, 'test3333')
  end

end