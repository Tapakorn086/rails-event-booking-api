class BookingsController < ApplicationController
  def create
    event = Event.find(params[:event_id])

    # 1. Build and validate booking object instantly for basic validations (email, quantity format)
    booking = event.bookings.build(booking_params)
    booking.status = :pending

    if booking.save
      # 2. Enqueue booking finalize processing async via Sidekiq
      ProcessBookingJob.perform_later(booking.id)

      # 3. Respond immediately with 202 Accepted and current pending status
      render json: BookingSerializer.new(booking).as_json, status: :accepted
    else
      render json: { error: booking.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def show
    event = Event.find(params[:event_id])
    booking = event.bookings.find(params[:id])

    render json: BookingSerializer.new(booking).as_json, status: :ok
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
