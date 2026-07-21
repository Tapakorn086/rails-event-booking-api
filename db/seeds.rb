# Sample events for Event Booking API
Booking.destroy_all
Event.destroy_all

event1 = Event.create!(
  name: "Coldplay Music of the Spheres World Tour",
  date: 1.month.from_now,
  capacity: 100
)

event2 = Event.create!(
  name: "Taylor Swift The Eras Tour",
  date: 2.months.from_now,
  capacity: 50
)

event3 = Event.create!(
  name: "Ed Sheeran +-=÷x Tour",
  date: 3.months.from_now,
  capacity: 5
)

puts "Seeded #{Event.count} events successfully."
