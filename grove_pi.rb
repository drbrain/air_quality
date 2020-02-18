require_relative "i2c"

class GrovePi
  ANALOG_READ           = 0x03
  ANALOG_WRITE          = 0x04
  PIN_MODE              = 0x05
  READ_FIRMWARE_VERSION = 0x08

  def initialize bus, address = 0x04
    @dev = I2C::Dev.new bus, address
  end

  def analog_read pin
    @dev.write [ANALOG_READ, pin, 0, 0]
    result = @dev.read nil, 3

    result.unpack("xS>").first
  end

  def firmware_version
    version = @dev.read READ_FIRMWARE_VERSION, 4

    version.unpack("C*").last 3
  end

  def pin_mode pin, mode:
    mode =
      case mode
      when :INPUT
        0
      when :OUTPUT
        1
      else
        raise ArgumentError, "Invalid pin mode #{mode}"
      end

    @dev.write [PIN_MODE, pin, mode, 0]
  end
end

if $0 == __FILE__ then
  grove_pi = GrovePi.new 1
  p grove_pi.firmware_version
end
