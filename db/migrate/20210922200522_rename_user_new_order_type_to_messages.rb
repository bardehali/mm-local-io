class RenameUserNewOrderTypeToMessages < ActiveRecord::Migration[6.0]
  def change
    User::Message.where(type: 'Users::NewOrder').update_all(type: 'User::NewOrder')
  end
end
