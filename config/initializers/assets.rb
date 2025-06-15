# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )

Rails.application.config.assets.precompile += %w(spree/backend/images/jquery.paste_image_reader.js spree/backend/products/editor.js spree/frontend_comp.js spree/backend/components/colorpicker.js spree/record_reviews.js spree/backend/products.scss spree/record_reviews.css.scss spree/scraper.css.scss ioffer/coming-soon.css ioffer/util.css ioffer/ioffer_landing.css ioffer/ioffer.css ioffer/select2.css ioffer/seller_landing.css ioffer/seller_landing.js ioffer/bootstrap.min.css ioffer/bootstrap.min.js ioffer/coming-soon.js ioffer/jquery.min.js ioffer/font-awesome-all.min.css bg.mp4 noimage/* selling/* feather.min.js)