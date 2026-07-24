#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/test_concurrency.rb
#
# Simulates two buyers racing to book the last available tickets simultaneously.
#
# Usage:
#   docker compose exec web ruby scripts/test_concurrency.rb
#
# Requires: Rails server running (normally via Docker compose)

require "net/http"
require "json"
require "uri"

BASE_URL = ENV.fetch("BASE_URL", "http://localhost:3000")

# ─── Helper Functions ─────────────────────────────────────────────────────────

def fetch_events(base_url)
  uri  = URI("#{base_url}/events")
  resp = Net::HTTP.get_response(uri)
  JSON.parse(resp.body)
rescue => e
  abort "❌ Connection failed: #{e.message}\n   Verify that the server is running at #{base_url}"
end

def post_booking(base_url, event_id, email, quantity)
  uri  = URI("#{base_url}/events/#{event_id}/bookings")
  http = Net::HTTP.new(uri.host, uri.port)
  req  = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
  req.body = JSON.generate({ booking: { email: email, quantity: quantity } })
  http.request(req)
rescue => e
  Struct.new(:code, :body).new("ERROR", e.message)
end

def poll_booking_status(base_url, event_id, booking_id)
  uri = URI("#{base_url}/events/#{event_id}/bookings/#{booking_id}")
  start_time = Time.now
  while (Time.now - start_time) < 3.0
    resp = Net::HTTP.get_response(uri) rescue nil
    if resp && resp.code == "200"
      booking = JSON.parse(resp.body)
      if booking["status"] != "pending"
        return booking
      end
    end
    sleep 0.05
  end
  nil
end

# ─── Load Current State ───────────────────────────────────────────────────────

events = fetch_events(BASE_URL)

if events.empty?
  abort "❌ No events found in database. Please run db:seed first."
end

# Choose event with available tickets (prefer the one with the smallest inventory)
event = events.select { |e| e["available_tickets"] > 0 }
              .min_by { |e| e["available_tickets"] }

if event.nil?
  abort "❌ All events are sold out. Reset DB with: docker compose down -v && docker compose up --build"
end

event_id = event["id"]
tickets_before = event["available_tickets"]
quantity_to_book = tickets_before # Try to buy everything left to trigger race condition

puts "============================================================"
puts "  [เตรียมตัวจำลอง] การทดสอบแย่งกันจองตั๋วพร้อมกัน (Race Condition)"
puts "============================================================"
puts "  คอนเสิร์ต  : #{event["name"]}"
puts "  รหัส Event : #{event_id}"
puts "  ตั๋วก่อนจอง  : #{tickets_before} ใบ"
puts "  สถานการณ์  : Alice และ Bob ยิงจองพร้อมกันคนละ #{quantity_to_book} ใบ"
puts "------------------------------------------------------------"
puts "  ⏳ เริ่มทำการส่งข้อมูลพร้อมกันเสี้ยววินาที..."
puts "============================================================"
puts ""

# ─── Concurrency Fire ─────────────────────────────────────────────────────────

results = []
mutex   = Mutex.new
barrier = Mutex.new
ready   = 0
start_signal = ConditionVariable.new

buyers = [
  { email: "alice@example.com", label: "Alice" },
  { email: "bob@example.com",   label: "Bob"   }
]

threads = buyers.map do |buyer|
  Thread.new do
    barrier.synchronize do
      ready += 1
      start_signal.wait(barrier) until ready >= buyers.size
      start_signal.broadcast
    end

    t0       = Time.now
    response = post_booking(BASE_URL, event_id, buyer[:email], quantity_to_book)
    elapsed  = (Time.now - t0).round(3)

    body = (JSON.parse(response.body) rescue nil)
    status_code = response.code.to_s

    if status_code == "202" && body && body["id"]
      final_booking = poll_booking_status(BASE_URL, event_id, body["id"])
      if final_booking
        status_code = final_booking["status"] == "success" ? "201" : "422"
        body = final_booking
        if final_booking["status"] == "failed"
          body = { "error" => final_booking["error_message"] }
        end
      else
        status_code = "TIMEOUT"
        body = { "error" => "Booking processing timed out" }
      end
    end

    result = {
      label:   buyer[:label],
      status:  status_code,
      body:    body || response.body,
      elapsed: elapsed
    }

    mutex.synchronize { results << result }
  end
end

threads.each(&:join)

# ─── Fetch Post-Booking State ─────────────────────────────────────────────────

updated_events = fetch_events(BASE_URL)
updated_event = updated_events.find { |e| e["id"] == event_id }
tickets_after = updated_event ? updated_event["available_tickets"] : -99

# ─── Output Results ───────────────────────────────────────────────────────────

puts "ผลลัพธ์การตอบรับจากระบบ:"
puts "-" * 60

results.sort_by { |r| r[:elapsed] }.each do |r|
  if r[:status] == "201"
    puts "✅ [สำเร็จ] #{r[:label]} จองตั๋วสำเร็จ!"
    puts "   ใช้เวลาตอบสนอง: #{r[:elapsed]} วินาที"
    puts "   ข้อมูลการจอง: ID = #{r[:body]['id']}, จำนวนจอง = #{r[:body]['quantity']} ใบ"
  else
    puts "❌ [ถูกปฏิเสธ] #{r[:label]} ถูกระบบปฏิเสธการจอง"
    puts "   ใช้เวลาตอบสนอง: #{r[:elapsed]} วินาที"
    puts "   ข้อความแจ้งเตือน: #{r[:body]['error']}"
  end
  puts ""
end

success_count = results.count { |r| r[:status] == "201" }

puts "============================================================"
puts "  สรุปผลข้อมูลคงเหลือหลังการทำงาน"
puts "============================================================"
puts "  ตั๋วเริ่มต้นทั้งหมด   : #{tickets_before} ใบ"
puts "  ผู้จองได้สำเร็จ     : #{success_count} คน"
puts "  ตั๋วคงเหลือจริงล่าสุด : #{tickets_after} ใบ"
puts "------------------------------------------------------------"

if success_count == 1 && tickets_after == 0
  puts "  📊 สรุป: ระบบทำการล็อกตั๋วแบบ Pessimistic Lock สำเร็จ!"
  puts "  ตั๋วถูกปล่อยขายให้คนแรกสุดเพียงคนเดียว ยอดคงเหลือเป็น 0 พอดี ไม่ติดลบ"
else
  puts "  ⚠️ สรุป: ผลลัพธ์ไม่เป็นไปตามคาดหมาย ตั๋วคงเหลือคลาดเคลื่อน"
end
puts "============================================================"
