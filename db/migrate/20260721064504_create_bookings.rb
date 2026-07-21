class CreateBookings < ActiveRecord::Migration[7.2]
  def change
    create_table :bookings do |t|
      t.references :event, null: false, foreign_key: true
      t.string :email
      t.integer :quantity

      t.timestamps
    end
  end
end
