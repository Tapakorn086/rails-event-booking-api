class Booking < ApplicationRecord
  belongs_to :event

  enum :status, { pending: "pending", success: "success", failed: "failed" }, default: "pending"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
end
