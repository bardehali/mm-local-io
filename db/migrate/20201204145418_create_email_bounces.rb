class CreateEmailBounces < ActiveRecord::Migration[6.0]
  def up
    create_table_unless_exists :email_bounces do |t|
      t.string :email, limit: 160
      t.string :subject, limit: 120
      t.timestamp :delivered_at
      t.text :reason
      t.index :email
      t.index :delivered_at
      t.index [:email, :delivered_at]
    end
  end

  def down
    drop_table_if_exists :email_bounces
  end
end
