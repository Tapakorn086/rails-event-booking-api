class BookingSerializer < ActiveModel::Serializer
  attributes :id, :event_id, :email, :quantity, :status, :error_message, :created_at
end
