require 'rails_helper'

RSpec.describe CreateBooking, type: :service do
  let(:event) { create(:event, capacity: 10) }

  describe '#call' do
    context 'when requested quantity is available and parameters are valid' do
      it 'processes a booking and returns success result' do
        booking = create(:booking, event: event, email: 'buyer@example.com', quantity: 2, status: :pending)
        service = CreateBooking.new(booking: booking)
        result = service.call

        expect(result).to be_success
        expect(result.booking).to be_persisted
        expect(result.booking.status).to eq('success')
        expect(event.reload.available_tickets).to eq(8)
      end
    end

    context 'when requested quantity exceeds available tickets' do
      it 'returns failure result and marks booking as failed' do
        booking = create(:booking, event: event, email: 'buyer@example.com', quantity: 15, status: :pending)
        service = CreateBooking.new(booking: booking)
        result = service.call

        expect(result).not_to be_success
        expect(result.error_message).to include('remaining') # "Only 10 ticket(s) remaining; you requested 15."
        expect(booking.reload.status).to eq('failed')
      end
    end

    describe 'concurrency test (pessimistic locking)' do
      it 'handles simultaneous booking requests for the last remaining ticket safely' do
        single_ticket_event = create(:event, capacity: 1)
        results = []

        threads = 2.times.map do |i|
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              booking = create(:booking, event: single_ticket_event, email: "user#{i}@example.com", quantity: 1, status: :pending)
              service = CreateBooking.new(booking: booking)
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
        expect(Booking.where(event: single_ticket_event, status: :success).count).to eq(1)
      end
    end
  end
end
