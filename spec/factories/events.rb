# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    name { "Rock Festival 2026" }
    date { 1.week.from_now }
    capacity { 10 }
  end
end
