# frozen_string_literal: true

# Use case: Process and finalize a pending booking for an event.
#
# Architecture notes:
#   - Processed asynchronously inside Sidekiq worker.
#   - Locks the event record via Pessimistic Locking to verify ticket availability.
#   - Mutates the booking status to either 'success' or 'failed' (with error message).
class CreateBooking
  Result = Struct.new(:success?, :booking, :error_message, keyword_init: true)

  def initialize(booking:)
    @booking  = booking
    @event    = booking.event
    @quantity = booking.quantity
  end

  def call
    @event.with_lock do
      if tickets_insufficient?
        error_msg = insufficient_tickets_message
        @booking.update!(status: :failed, error_message: error_msg)
        return Result.new(success?: false, booking: @booking, error_message: error_msg)
      end

      @booking.update!(status: :success)
      Result.new(success?: true, booking: @booking, error_message: nil)
    end
  rescue => e
    @booking.update!(status: :failed, error_message: e.message)
    Result.new(success?: false, booking: @booking, error_message: e.message)
  end

  private

  def tickets_insufficient?
    available = @event.capacity - @event.bookings.where(status: :success).sum(:quantity)
    available < @quantity
  end

  def insufficient_tickets_message
    available = @event.capacity - @event.bookings.where(status: :success).sum(:quantity)
    if available.zero?
      "This event is sold out."
    else
      "Only #{available} ticket(s) remaining; you requested #{@quantity}."
    end
  end
end
