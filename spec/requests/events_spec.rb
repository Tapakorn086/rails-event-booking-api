require 'rails_helper'

RSpec.describe 'Events and Bookings API', type: :request do
  describe 'GET /events' do
    it 'returns all events with proper serializer format' do
      event1 = create(:event, name: 'Concert A', capacity: 100)
      event2 = create(:event, name: 'Concert B', capacity: 50)
      create(:booking, event: event1, quantity: 20)

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
      it 'creates a booking and returns 201 Created' do
        post "/events/#{event.id}/bookings", params: { email: 'fan@example.com', quantity: 3 }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)

        expect(json).to include(
          'event_id' => event.id,
          'email' => 'fan@example.com',
          'quantity' => 3
        )
        expect(json).to have_key('id')
        expect(json).to have_key('created_at')
        expect(event.reload.available_tickets).to eq(2)
      end
    end

    context 'when tickets are insufficient' do
      it 'rejects request with 422 Unprocessable Entity and clear error message' do
        post "/events/#{event.id}/bookings", params: { email: 'fan@example.com', quantity: 10 }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json['error']).to include('Not enough tickets available')
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
