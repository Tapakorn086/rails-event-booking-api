class Booking < ApplicationRecord
  belongs_to :event

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
end
