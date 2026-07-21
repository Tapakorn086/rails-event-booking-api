require 'rails_helper'

RSpec.describe CreateBooking, type: :service do
  let(:event) { create(:event, capacity: 10) }

  describe '#call' do
    context 'when requested quantity is available and parameters are valid' do
      it 'creates a booking and returns success result' do
        service = CreateBooking.new(event: event, email: 'buyer@example.com', quantity: 2)
        result = service.call

        expect(result).to be_success
        expect(result.booking).to be_persisted
        expect(result.booking.email).to eq('buyer@example.com')
        expect(result.booking.quantity).to eq(2)
        expect(event.reload.available_tickets).to eq(8)
      end
    end

    context 'when requested quantity exceeds available tickets' do
      it 'returns failure result without creating a booking' do
        service = CreateBooking.new(event: event, email: 'buyer@example.com', quantity: 15)
        result = service.call

        expect(result).not_to be_success
        expect(result.error_message).to include('Not enough tickets available')
        expect(Booking.count).to eq(0)
      end
    end

    context 'when validation fails (invalid email)' do
      it 'returns failure result with validation error' do
        service = CreateBooking.new(event: event, email: 'invalid-email', quantity: 1)
        result = service.call

        expect(result).not_to be_success
        expect(result.error_message).to include('Email is invalid')
        expect(Booking.count).to eq(0)
      end
    end

    describe 'concurrency test (pessimistic locking)' do
      it 'handles simultaneous booking requests for the last remaining ticket safely' do
        single_ticket_event = create(:event, capacity: 1)
        results = []

        threads = 2.times.map do |i|
          Thread.new do
            # Ensure fresh DB connection for each thread
            ActiveRecord::Base.connection_pool.with_connection do
              service = CreateBooking.new(
                event: single_ticket_event,
                email: "user#{i}@example.com",
                quantity: 1
              )
              results << service.call
            end
          end
        end

        threads.each(&:join)

        successes = results.select(&:success?)
        failures = results.reject(&:success?)

        expect(successes.count).to eq(1)
        expect(failures.count).to eq(1)
        expect(single_ticket_event.reload.available_tickets).to eq(0)
        expect(Booking.where(event: single_ticket_event).count).to eq(1)
      end
    end
  end
end
