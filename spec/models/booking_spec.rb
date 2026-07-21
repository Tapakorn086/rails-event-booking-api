require 'rails_helper'

RSpec.describe Booking, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      booking = build(:booking)
      expect(booking).to be_valid
    end

    it 'is invalid without an email' do
      booking = build(:booking, email: nil)
      expect(booking).not_to be_valid
      expect(booking.errors[:email]).to include("can't be blank")
    end

    it 'is invalid with bad email format' do
      booking = build(:booking, email: 'invalid_email')
      expect(booking).not_to be_valid
      expect(booking.errors[:email]).to include('is invalid')
    end

    it 'is invalid with quantity less than or equal to 0' do
      booking_zero = build(:booking, quantity: 0)
      expect(booking_zero).not_to be_valid

      booking_neg = build(:booking, quantity: -2)
      expect(booking_neg).not_to be_valid
    end
  end
end
