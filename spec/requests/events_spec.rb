require 'rails_helper'

RSpec.describe 'Events and Bookings API', type: :request do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /events' do
    it 'returns all events with proper serializer format' do
      event1 = create(:event, name: 'Concert A', capacity: 100)
      event2 = create(:event, name: 'Concert B', capacity: 50)
      create(:booking, event: event1, quantity: 20, status: :success)

      get '/events'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json.size).to eq(2)
      expect(json.first).to include(
        'id' => event1.id,
        'name' => 'Concert A',
        'available_tickets' => 80
      )
      expect(json.second).to include(
        'id' => event2.id,
        'name' => 'Concert B',
        'available_tickets' => 50
      )
    end
  end

  describe 'POST /events/:event_id/bookings' do
    let!(:event) { create(:event, capacity: 5) }

    context 'with valid parameters and sufficient ticket availability' do
      it 'creates a booking and returns 202 Accepted' do
        expect {
          post "/events/#{event.id}/bookings", params: { email: 'fan@example.com', quantity: 3 }
        }.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:accepted)
        json = JSON.parse(response.body)

        expect(json).to include(
          'event_id' => event.id,
          'email' => 'fan@example.com',
          'quantity' => 3,
          'status' => 'pending'
        )
        expect(json).to have_key('id')
        expect(json).to have_key('created_at')
        
        # Perform background enqueued jobs
        perform_enqueued_jobs

        expect(Booking.last.status).to eq('success')
        expect(event.reload.available_tickets).to eq(2)
      end
    end

    context 'when tickets are insufficient' do
      it 'accepts request immediately but marks booking as failed' do
        post "/events/#{event.id}/bookings", params: { email: 'fan@example.com', quantity: 10 }

        expect(response).to have_http_status(:accepted)
        
        perform_enqueued_jobs
        
        booking = Booking.last
        expect(booking.status).to eq('failed')
        expect(booking.error_message).to include('Only 5 ticket(s) remaining')
      end
    end

    context 'when params fail validation' do
      it 'rejects request with 422 Unprocessable Entity for invalid email' do
        post "/events/#{event.id}/bookings", params: { email: 'invalid-email-format', quantity: 1 }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json['error']).to include('Email is invalid')
      end
    end
  end
end
