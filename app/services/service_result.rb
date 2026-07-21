# ServiceResult encapsulates the output of a Service Object / Use Case operation.
# It enforces predictable responses without raising exceptions for expected business errors.
class ServiceResult
  attr_reader :booking, :error_message, :errors

  def initialize(success:, booking: nil, error_message: nil, errors: [])
    @success = success
    @booking = booking
    @error_message = error_message
    @errors = errors
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
