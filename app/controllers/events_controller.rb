class EventsController < ApplicationController
  def index
    events = Event.all
    render json: events, each_serializer: EventSerializer, status: :ok
  end
end
