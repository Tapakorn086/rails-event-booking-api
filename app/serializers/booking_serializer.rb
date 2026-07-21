class BookingSerializer < ActiveModel::Serializer
  attributes :id, :event_id, :email, :quantity, :created_at
end
