class AddErrorMessageToBookings < ActiveRecord::Migration[7.2]
  def change
    add_column :bookings, :error_message, :string
  end
end
