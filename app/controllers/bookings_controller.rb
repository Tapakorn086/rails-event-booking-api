class BookingsController < ApplicationController
  def create
    event = Event.find_by(id: params[:event_id])
    
    result = CreateBooking.new(
      event: event,
      email: booking_params[:email],
      quantity: booking_params[:quantity].to_i
    ).call

    if result.success?
      render json: result.booking, serializer: BookingSerializer, status: :created
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end

  private

  def booking_params
    params.permit(:email, :quantity)
  end
end
