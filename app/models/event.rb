class Event < ApplicationRecord
  has_many :bookings, dependent: :destroy

  validates :name, presence: true
  validates :date, presence: true
  validates :capacity, presence: true, numericality: { greater_than: 0, only_integer: true }

  def available_tickets
    capacity - bookings.where(status: [:success, :pending]).sum(:quantity)
  end
end
