# spec/factories/bookings.rb
FactoryBot.define do
  factory :booking do
    association :event
    email { "user@example.com" }
    quantity { 2 }
  end
end
