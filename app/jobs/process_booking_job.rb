# frozen_string_literal: true

class ProcessBookingJob < ApplicationJob
  queue_as :default

  def perform(booking_id)
    booking = Booking.find(booking_id)
    return unless booking.pending?

    CreateBooking.new(booking: booking).call
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Booking with ID #{booking_id} not found."
  end
end
