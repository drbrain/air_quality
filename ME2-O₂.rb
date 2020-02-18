require_relative "grove_pi"

class ME2_O₂
  BASELINE = 20.8
  PREHEAT_TIME = 60

  attr_reader :calibration

  def initialize bus, pin, preheat: false
    @pin = pin

    @pi = GrovePi.new bus
    @pi.pin_mode @pin, mode: :INPUT

    sleep PREHEAT_TIME if preheat

    calibrate
  end

  def calibrate
    total = 100.times.map do
      sleep 0.1
      @pi.analog_read @pin
    rescue Errno::EREMOTEIO
      retry
    end.sum

    @calibration = total / 100.0 / BASELINE
  end

  def read
    total = 10.times.map do
      sleep 0.1
      @pi.analog_read @pin
    rescue Errno::EREMOTEIO
      retry
    end.sum

    average = total / 10.0

    average / @calibration
  end
end

if $0 == __FILE__ then
  pin = ARGV.shift || 0
  pin = Integer pin

  sensor = ME2_O₂.new 1, pin

  puts "calibration: #{sensor.calibration}"

  loop do
    oxygen = sensor.read

    puts "O₂ %0.2f%%" % oxygen

    sleep 1
  end
end

