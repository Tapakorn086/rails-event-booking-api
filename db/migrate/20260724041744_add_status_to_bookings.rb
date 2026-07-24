class AddStatusToBookings < ActiveRecord::Migration[7.2]
  def change
    add_column :bookings, :status, :string, default: "pending", null: false
  end
end
