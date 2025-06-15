class AddImageToUserMessages < ActiveRecord::Migration[6.0]
  def up
    add_column_unless_exists :user_messages, :image, :string, length: 255
  end

  def down
    remove_column_if_exists :user_messages, :image
  end
end
