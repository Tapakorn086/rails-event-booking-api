#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/test_concurrency.rb
#
# จำลองสองคนจองตั๋วใบสุดท้ายพร้อมกันผ่าน HTTP
# รัน: ruby scripts/test_concurrency.rb
#
# ต้องการ: rails server ทำงานอยู่ที่ localhost:3000
#          และมี event ที่ id=3 (Jazz at the River, capacity=50)

require "net/http"
require "json"
require "uri"

BASE_URL   = "http://localhost:3000"
# ใช้ event ที่ 3 (Jazz at the River) ซึ่งมี capacity=50
# ถ้าต้องการทดสอบ race condition ให้แน่ชัด ควรสร้าง event ใหม่ที่มี capacity=1
EVENT_ID   = ENV.fetch("EVENT_ID", "3")
QUANTITY   = ENV.fetch("QUANTITY", "50").to_i  # จองทั้งหมดพร้อมกัน

puts "=" * 60
puts "Concurrency Test: Two buyers racing for the last ticket"
puts "Event ID : #{EVENT_ID}"
puts "Quantity : #{QUANTITY} each (total capacity should be #{QUANTITY})"
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
    response = post_booking(EVENT_ID, buyer[:email], QUANTITY)
    elapsed  = (Time.now - start_at).round(3)

    result = {
      label:    buyer[:label],
      status:   response.code,
      body:     JSON.parse(response.body) rescue response.body,
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
