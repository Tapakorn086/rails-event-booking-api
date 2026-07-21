require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      event = build(:event)
      expect(event).to be_valid
    end

    it 'is invalid without a name' do
      event = build(:event, name: nil)
      expect(event).not_to be_valid
      expect(event.errors[:name]).to include("can't be blank")
    end

    it 'is invalid without a date' do
      event = build(:event, date: nil)
      expect(event).not_to be_valid
      expect(event.errors[:date]).to include("can't be blank")
    end

    it 'is invalid with capacity less than or equal to 0' do
      event_zero = build(:event, capacity: 0)
      expect(event_zero).not_to be_valid

      event_negative = build(:event, capacity: -5)
      expect(event_negative).not_to be_valid
    end
  end

  describe '#available_tickets' do
    it 'calculates available tickets correctly based on total capacity and existing bookings' do
      event = create(:event, capacity: 10)
      create(:booking, event: event, quantity: 3)
      create(:booking, event: event, quantity: 2)

      expect(event.available_tickets).to eq(5)
    end
  end
end
