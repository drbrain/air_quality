require_relative "grove_pi"

##
# WebPlotDigitizer and plot.ly say the CO roughly fits the equation:
#
#   Rs/Ro =
#     0.7270731131275204 +
#     1.697568399285764 **
#     (-0.003147756584258994 * CO ppm)

class MQ_9
  def initialize bus, pin, r0: nil
    @pin = pin
    @R0  = r0

    @pi = GrovePi.new bus
    @pi.pin_mode @pin, mode: :INPUT
  end

  def concentration_CO samples: 10
    rs_gas = self.Rs_gas samples: samples

    ratio = rs_gas / @R0

    concentration = -600.318 * Math.log10(ratio - 0.727)

    return 0    if concentration < 200
    return 2000 if concentration > 2000

    concentration
  end

  ##
  # Calculate R0 for calibration in clean air

  def R0 baseline: 10.8 # CO baseline at 1000ppm per datasheet
    total = 100.times.map do
      sleep 0.1
      sensor.read samples: 1
      @pi.analog_read @pin
    rescue Errno::EREMOTEIO
      retry
    end.sum

    average = total / 100.0

    volts = average / 1024 * 5

    rs_air = (5 - volts) / volts

    rs_air / 10.8
  end

  def Rs_gas samples: 10
    value = read samples: samples

    volts = value / 1024 * 5

    (5 - volts) / volts
  end

  def read samples: 10
    total = samples.times.map do
      sleep 0.1 if samples > 1
      @pi.analog_read @pin
    rescue Errno::EREMOTEIO
      retry
    end.sum

    total / samples.to_f
  end
end

if $0 == __FILE__ then
  pin = ARGV.shift || 0
  pin = Integer pin

  # R0 calibrated for my sensor
  sensor = MQ_9.new 1, pin, r0: 0.7067229934368695

  loop do
    puts "concentration CO: %4dppm" % sensor.concentration_CO

    sleep 1
  end
end

