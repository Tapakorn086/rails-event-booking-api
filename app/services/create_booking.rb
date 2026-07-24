# frozen_string_literal: true

# Use case: Create a booking for an event.
#
# Architecture notes:
#   - Lives in the Service layer; knows nothing about HTTP, params, or controllers.
#   - Receives already-cast arguments via constructor (dependency injection pattern).
#   - Returns a Result value object so callers never need to rescue exceptions.
#
# ARCHITECTURAL DECISION — Pessimistic Locking:
#   event.with_lock issues SELECT ... FOR UPDATE, serialising access so that two
#   concurrent requests cannot both pass the availability check for the same seat.
#   Optimistic locking would raise StaleObjectError on the second writer, requiring
#   a retry loop that still ends in failure — extra roundtrips, worse UX.
class CreateBooking
  # Immutable value object returned by #call.
  Result = Struct.new(:success?, :booking, :error_message, keyword_init: true)

  def initialize(event:, email:, quantity:)
    @event    = event
    @email    = email
    @quantity = quantity
  end

  def call
    @event.with_lock do
      return insufficient_tickets_result if tickets_insufficient?

      booking = @event.bookings.build(email: @email, quantity: @quantity)

      if booking.save
        Result.new(success?: true, booking: booking, error_message: nil)
      else
        Result.new(
          success?:      false,
          booking:       nil,
          error_message: booking.errors.full_messages.to_sentence
        )
      end
    end
  end

  private

  def tickets_insufficient?
    @event.available_tickets < @quantity
  end

  def insufficient_tickets_result
    available = @event.available_tickets
    message   = if available.zero?
                  "This event is sold out."
                else
                  "Only #{available} ticket(s) remaining; you requested #{@quantity}."
                end

    Result.new(success?: false, booking: nil, error_message: message)
  end
end
