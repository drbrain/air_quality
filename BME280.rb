require_relative "i2c"

class BME280
  class Error < RuntimeError
  end

  # Settings

  # Oversampling modes
  OSAMPLE_OFF = 0
  OSAMPLE_1   = 1
  OSAMPLE_2   = 2
  OSAMPLE_4   = 3
  OSAMPLE_8   = 4
  OSAMPLE_16  = 5

  # Standby settings
  STANDBY_0_5  = 0
  STANDBY_62_5 = 1
  STANDBY_125  = 2
  STANDBY_250  = 3
  STANDBY_500  = 4
  STANDBY_1000 = 5
  STANDBY_10   = 6
  STANDBY_20   = 7

  # Filter settings
  FILTER_OFF = 0
  FILTER_2   = 1
  FILTER_4   = 2
  FILTER_8   = 3
  FILTER_16  = 4

  # Operation modes
  SLEEP  = 0x00
  FORCED = 0x01
  NORMAL = 0x03

  # Registers

  # temperature compensation
  DIG_T1 = 0x88
  DIG_T2 = 0x8A
  DIG_T3 = 0x8C

  # pressure compensation
  DIG_P1 = 0x8E
  DIG_P2 = 0x90
  DIG_P3 = 0x92
  DIG_P4 = 0x94
  DIG_P5 = 0x96
  DIG_P6 = 0x98
  DIG_P7 = 0x9A
  DIG_P8 = 0x9C
  DIG_P9 = 0x9E

  # humidity compensation
  DIG_H1  = 0xA1
  DIG_H2  = 0xE1
  DIG_H3  = 0xE3
  DIG_H4a = 0xE4
  DIG_H4b = 0xE5
  DIG_H5a = 0xE5
  DIG_H5b = 0xE6
  DIG_H6  = 0xE7

  CHIP_ID   = 0xD0
  SOFTRESET = 0xE0

  CTRL_HUM  = 0xF2
  STATUS    = 0xF3
  CTRL_MEAS = 0xF4
  CONFIG    = 0xF5
  DATA      = 0xF7

  # Compensation constants

  HUMIDITY_MIN =   0.0
  HUMIDITY_MAX = 100.0

  PRESSURE_MIN =  30_000.0
  PRESSURE_MAX = 110_000.0

  TEMPERATURE_MIN = -40
  TEMPERATURE_MAX =  85

  def initialize bus, address = 0x77,
                 mode: NORMAL,
                 standby: STANDBY_1000,
                 filter: FILTER_OFF,
                 humidity_oversample: OSAMPLE_1,
                 pressure_oversample: OSAMPLE_1,
                 temperature_oversample: OSAMPLE_1

    raise Error, "Invalid mode value #{mode}" unless
      mode >= SLEEP && mode <= NORMAL

    @mode = mode

    raise Error, "Invalid standby value #{standby}" unless
      standby >= STANDBY_0_5 && standby <= STANDBY_20

    @standby = standby

    raise Error, "Invalid filter value #{filter}" unless
      filter >= FILTER_OFF && filter <= FILTER_16

    @filter = filter

    raise Error, "Invalid humidity oversampling #{humidity_oversample}" unless
      humidity_oversample >= OSAMPLE_OFF && humidity_oversample <= OSAMPLE_16

    @humidity_oversample = humidity_oversample

    raise Error, "Invalid pressure oversampling #{pressure_oversample}" unless
      pressure_oversample >= OSAMPLE_OFF && pressure_oversample <= OSAMPLE_16

    @pressure_oversample = pressure_oversample

    raise Error, "Invalid temperature oversampling #{temperature_oversample}" unless
      temperature_oversample >= OSAMPLE_OFF &&
      temperature_oversample <= OSAMPLE_16

    @temperature_oversample = temperature_oversample

    @dev = I2C::Dev.new bus, address

    @t_fine    = 0
    @last_data = nil

    load_calibration

    configure
  end

  def configure
    config    = @standby << 5 | @filter << 2
    ctrl_meas = @temperature_oversample << 5 |
                @pressure_oversample << 2 |
                @mode
    ctrl_hum = @humidity_oversample

    # Allow access to all registers
    @dev.write [CTRL_MEAS, SLEEP]

    # Write configuration, enabling selected mode
    @dev.write [CONFIG, config]
    @dev.write [CTRL_HUM, ctrl_hum]
    @dev.write [CTRL_MEAS, ctrl_meas]
  end

  def data
    [temperature, pressure / 1_000, humidity]
  end

  def humidity
    var1 = @t_fine - 76800.0
    var2 = @dig_H4 * 64.0 + (@dig_H5 / 16384.0) * var1
    var3 = raw_humidity - var2
    var4 = @dig_H2 / 65536.0
    var5 = 1.0 + (@dig_H3 / 67108864.0) * var1
    var6 = 1.0 + (@dig_H6 / 67108864.0) * var1 * var5
    var6 = var3 * var4 * (var5 * var6)

    hum = var6 * (1.0 - @dig_H1 * var6 / 524288.0)

    hum = [hum, HUMIDITY_MIN].max
    [hum, HUMIDITY_MAX].min
  end

  def load_calibration
    @dig_T1 = @dev.read_U16 DIG_T1
    @dig_T2 = @dev.read_S16 DIG_T2
    @dig_T3 = @dev.read_S16 DIG_T3

    @dig_P1 = @dev.read_U16 DIG_P1
    @dig_P2 = @dev.read_S16 DIG_P2
    @dig_P3 = @dev.read_S16 DIG_P3
    @dig_P4 = @dev.read_S16 DIG_P4
    @dig_P5 = @dev.read_S16 DIG_P5
    @dig_P6 = @dev.read_S16 DIG_P6
    @dig_P7 = @dev.read_S16 DIG_P7
    @dig_P8 = @dev.read_S16 DIG_P8
    @dig_P9 = @dev.read_S16 DIG_P9

    @dig_H1 = @dev.read_U8 DIG_H1
    @dig_H2 = @dev.read_S16 DIG_H2
    @dig_H3 = @dev.read_U8 DIG_H3

    e4 = @dev.read_S8 DIG_H4a
    e5 = @dev.read_S8 DIG_H4b
    e6 = @dev.read_S8 DIG_H5b

    @dig_H4 = (e4 << 4) | (e5 & 0x0F)
    @dig_H5 = (e6 << 4) | ((e5 >> 4) & 0x0F)
    @dig_H6 = @dev.read_S8 DIG_H6
  end

  def measuring
    value = @dev.read_S8 STATUS
    value & 0x08
  end

  def pressure
    var1 = @t_fine / 2.0 - 64000.0
    var2 = var1 * var1 * @dig_P6 / 32768.0
    var2 = var2 + var1 * @dig_P5 * 2.0
    var2 = (var2 / 4.0) + @dig_P4 * 65536.0
    var3 = @dig_P3 * var1 * var1 / 524288.0
    var1 = (var3 + @dig_P2 * var1) / 524288.0
    var1 = (1.0 + var1 / 32768.0) * @dig_P1

    return PRESSURE_MIN if var1 <= 0

    pres = 1048576.0 - raw_pressure
    pres = (pres - var2 / 4096.0) * 6250.0 / var1
    var1 = @dig_P9 * pres * pres / 2147483648.0
    var2 = pres * @dig_P8 / 32768.0
    pres = pres + (var1 + var2 + @dig_P7) / 16.0

    pres = [pres, PRESSURE_MIN].max
    [pres, PRESSURE_MAX].min
  end

  def raw_humidity
    @last_data.unpack("@6S>").first
  end

  def raw_pressure
    h, l = @last_data.unpack("S>C")
    h << 4 | l >> 4
  end

  def raw_temperature
    h, l = @last_data.unpack("@3S>C")
    h << 4 | l >> 4
  end

  def read_raw_data
    @last_data = @dev.read DATA, 8
  end

  def readable?
    measuring.zero?
  end

  def temperature
    temp = Float raw_temperature

    var1 = (temp / 16384.0) - (@dig_T1 / 1024.0)
    var1 *= @dig_T2

    var2 = (temp / 131072.0) - (@dig_T1 / 8192.0)
    var2 = (var2 * var2) * @dig_T3

    @t_fine = Integer var1 + var2

    temp = (var1 + var2) / 5120.0

    temp = [temp, TEMPERATURE_MIN].max
    [temp, TEMPERATURE_MAX].min
  end

end

if $0 == __FILE__ then
  bme280 = BME280.new 1, 0x76

  loop do
    sleep 0.001 until bme280.readable?
    bme280.read_raw_data
    puts "%4.1f℃ %5.1fhPa %4.1f%%RH" % bme280.data

    sleep 1
  end
end
