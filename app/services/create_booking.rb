# Use Case Service Object responsible for creating a concert ticket booking.
#
# ARCHITECTURAL DECISION:
# Pessimistic Locking (`event.with_lock`) is used to prevent overbooking / race conditions when multiple
# requests attempt to book the last remaining tickets simultaneously.
# Locking the event row issuing `SELECT ... FOR UPDATE` ensures serialized access to ticket availability check
# and booking creation within a DB transaction.
class CreateBooking
  def initialize(event:, email:, quantity:)
    @event = event
    @email = email
    @quantity = quantity
  end

  def call
    return ServiceResult.new(success: false, error_message: "Event does not exist") if @event.nil?

    # Wrap concurrency-sensitive check + insertion within a pessimistic row-level lock
    @event.with_lock do
      available = @event.available_tickets

      if available < @quantity
        return ServiceResult.new(
          success: false,
          error_message: "Not enough tickets available. Remaining tickets: #{available}"
        )
      end

      booking = @event.bookings.build(email: @email, quantity: @quantity)

      if booking.save
        ServiceResult.new(success: true, booking: booking)
      else
        ServiceResult.new(
          success: false,
          error_message: booking.errors.full_messages.join(", "),
          errors: booking.errors.full_messages
        )
      end
    end
  end
end
