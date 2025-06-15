class SetCountryCodeToReviewers < ActiveRecord::Migration[6.0]
  def change
    countries_cache = {}
    # Not using includes(:user) because possible deleted user already
    Spree::Review.all.each do|review|
      user = Spree::User.unscoped.find_by id: review.user_id
      if user && user.country.present? && user.country_code.blank?
        country = countries_cache[user.country.downcase] || Spree::Country.find_by(name: user.country)
        countries_cache[user.country.downcase] ||= country
        user.update(country_code: country&.iso&.downcase)
      end
    end
  end
end
