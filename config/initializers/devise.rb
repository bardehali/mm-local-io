Devise.secret_key = '0f4b45ca140b7476c91ab658b37ce16ebd52948236e9d9aa32140ab2d903d76f2883970bea67594dd05d2d89d629286b268f'

#Devise.setup do |config|
  # Required so users don't lose their carts when they need to confirm.
  # config.allow_unconfirmed_access_for = 1.days

  # Fixes the bug where Confirmation errors result in a broken page.
  # config.router_name = :spree

  # Add any other devise configurations here, as they will override the defaults provided by spree_auth_devise.
#end