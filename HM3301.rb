require_relative "i2c"

class HM3301

  class Error < RuntimeError
  end

  USE_I2C = "\x88"
  FRAMES  = 29

  attr_reader :PM_1_0_standard_particulate
  attr_reader :PM_2_5_standard_particulate
  attr_reader :PM_10_standard_particulate

  attr_reader :PM_1_0_atmospheric_environment
  attr_reader :PM_2_5_atmospheric_environment
  attr_reader :PM_10_atmospheric_environment

  def initialize bus, address = 0x40
    @dev = I2C::Dev.new bus, address

    I2C::Message.write @dev, USE_I2C
    
    # Standard particulate matter concentrations in µg/m³
    @PM_1_0_standard_particulate = 0
    @PM_2_5_standard_particulate = 0
    @PM_10_standard_particulate  = 0

    # Atmospheric environment concentration in µg/m³
    @PM_1_0_atmospheric_environment = 0
    @PM_2_5_atmospheric_environment = 0
    @PM_10_atmospheric_environment  = 0
  end

  def atmospheric_environment
    [
      @PM_1_0_atmospheric_environment,
      @PM_2_5_atmospheric_environment,
      @PM_10_atmospheric_environment,
    ]
  end

  def check_crc result
    data = result.bytes
    expected_crc = data.pop

    crc = data.reduce(0) { |byte, crc|
      crc += byte
    }

    (crc & 0xff) == expected_crc
  end

  def read
    message = I2C::Message.read @dev, FRAMES
    result = message.buffer.to_s FRAMES

    raise Error, "invalid CRC" unless check_crc result

    result = result.unpack "xxnnnnnn"

    @PM_1_0_standard_particulate = result[0]
    @PM_2_5_standard_particulate = result[1]
    @PM_10_standard_particulate  = result[2]

    @PM_1_0_atmospheric_environment = result[3]
    @PM_2_5_atmospheric_environment = result[4]
    @PM_10_atmospheric_environment  = result[5]
  end

  def standard_particulate
    [
      @PM_1_0_standard_particulate,
      @PM_2_5_standard_particulate,
      @PM_10_standard_particulate,
    ]
  end
end

  if $0 == __FILE__ then
    hm3301 = HM3301.new 1

    loop do
      hm3301.read
      puts "Standard particulate matter PM 1.0: %3d PM 2.5: %3d PM 10: %3d" %
        hm3301.standard_particulate
      puts "Atmospheric environment     PM 1.0: %3d PM 2.5: %3d PM 10: %3d" %
        hm3301.atmospheric_environment
      puts

      sleep 1
    end
  end
