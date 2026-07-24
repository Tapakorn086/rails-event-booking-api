#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/test_concurrency.rb
#
# Simulates two buyers racing to book the last available tickets simultaneously.
#
# Usage:
#   podman exec -it rails_test-web-1 ruby scripts/test_concurrency.rb
#

require "net/http"
require "json"
require "uri"

BASE_URL = "http://localhost:3000"

def fetch_events
  uri  = URI("#{BASE_URL}/events")
  resp = Net::HTTP.get_response(uri)
  JSON.parse(resp.body)
rescue => e
  abort "❌ Connection failed: #{e.message}\n   Verify that the server is running at #{BASE_URL}"
end

events = fetch_events
if events.empty?
  abort "❌ No events found in database. Please run db:seed first."
end

# Pick the event with the smallest available tickets (> 0)
event = events.select { |e| e["available_tickets"] > 0 }
              .min_by { |e| e["available_tickets"] }

if event.nil?
  abort "❌ All events are sold out. Reset DB with db:seed."
end

event_id = event["id"]
available_tickets = event["available_tickets"]

puts "=" * 60
puts "Concurrency Test: Two buyers racing for the last tickets"
puts "Event      : #{event['name']}"
puts "Event ID   : #{event_id}"
puts "Available  : #{available_tickets} tickets"
puts "Quantity   : #{available_tickets} each"
puts "=" * 60
puts

results = []
mutex   = Mutex.new

def post_booking(event_id, email, quantity)
  uri  = URI("#{BASE_URL}/events/#{event_id}/bookings")
  http = Net::HTTP.new(uri.host, uri.port)
  req  = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
  req.body = JSON.generate({ booking: { email: email, quantity: quantity } })
  http.request(req)
rescue => e
  Struct.new(:code, :body).new("ERROR", e.message)
end

threads = [
  { email: "alice@example.com", label: "Alice" },
  { email: "bob@example.com",   label: "Bob"   }
].map do |buyer|
  Thread.new do
    start_at = Time.now
    response = post_booking(event_id, buyer[:email], available_tickets)
    elapsed  = (Time.now - start_at).round(3)

    result = {
      label:    buyer[:label],
      status:   response.code,
      body:     (JSON.parse(response.body) rescue response.body),
      elapsed:  elapsed
    }

    mutex.synchronize { results << result }
  end
end

threads.each(&:join)

puts "Results:"
puts "-" * 60
results.each do |r|
  icon = r[:status] == "201" ? "✅" : "❌"
  puts "#{icon} #{r[:label]} — HTTP #{r[:status]} (#{r[:elapsed]}s)"
  puts "   #{JSON.pretty_generate(r[:body]).gsub("\n", "\n   ")}"
  puts
end

successes = results.count { |r| r[:status] == "201" }
puts "=" * 60
puts "Summary: #{successes}/2 succeeded"
puts successes == 1 ? "✅ Pessimistic lock worked — exactly 1 winner!" : "⚠️  Unexpected result"
