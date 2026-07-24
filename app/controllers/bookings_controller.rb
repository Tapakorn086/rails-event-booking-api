class BookingsController < ApplicationController
  def create
    event = Event.find(params[:event_id])

    result = CreateBooking.new(
      event:    event,
      email:    booking_params[:email],
      quantity: booking_params[:quantity].to_i
    ).call

    if result.success?
      render json: BookingSerializer.new(result.booking).as_json, status: :created
    else
      render json: { error: result.error_message }, status: :unprocessable_entity
    end
  end

  private

  def booking_params
    if params[:booking].present?
      params.require(:booking).permit(:email, :quantity)
    else
      params.permit(:email, :quantity)
    end
  end
end
