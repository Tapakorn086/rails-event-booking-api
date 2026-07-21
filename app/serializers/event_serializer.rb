class EventSerializer < ActiveModel::Serializer
  attributes :id, :name, :date, :available_tickets
end
