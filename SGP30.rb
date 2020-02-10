require_relative "i2c"

class SGP30
  class Error < RuntimeError
  end

  # Commands

  IAQ_INIT                    = ["\x20\x03", 0, 0,  10]
  MEASURE_IAQ                 = ["\x20\x08", 0, 6,  12, "S>S>"]
  GET_IAQ_BASELINE            = ["\x20\x15", 0, 6,  10, "S>S>"]
  SET_IAQ_BASELINE            = ["\x20\x1e", 6, 0,  10, "S>S>"]
  SET_ABSOLUTE_HUMIDITY       = ["\x20\x61", 3, 0,  10, "S>"]
  MEASURE_TEST                = ["\x20\x32", 0, 3, 220, "S>"]
  GET_FEATURE_SET             = ["\x20\x2f", 0, 3,  10, "S>"]
  MEASURE_RAW                 = ["\x20\x50", 0, 6,  25, "S>S>"]
  GET_TVOC_INCEPTIVE_BASELINE = ["\x20\xb3", 0, 3,  10, "S>"]
  SET_TVOC_BASELINE           = ["\x20\x77", 3, 0,  10, "S>"]

  def initialize bus, address = 0x58
    @dev = I2C::Dev.new bus, address

    iaq_init

    set_tvoc_baseline get_tvoc_inceptive_baseline if features == 0x0022
  end

  def apply_crc data
    data.bytes.each_slice(2).flat_map { |pair|
      pair << crc(pair)
    }.pack "C*"
  end

  def crc pair
    pair.reduce(0xFF) { |byte, crc|
      8.times do
        if ((byte ^ crc) & 0x80) == 0x80 then
          crc = (crc << 1) ^ 0x31
        else
          crc <<= 1
        end

        byte <<= 1
      end

      crc &= 0xFF
    }
  end

  def extract_data data
    data.bytes.each_slice(3).flat_map { |a, b, given_crc|
      data = [a, b]
      expected_crc = crc data

      raise Error, "invalid CRC" unless expected_crc == given_crc

      data
    }.pack "C*"
  end

  def iaq_init
    send_command IAQ_INIT
  end

  def features
    result = send_command GET_FEATURE_SET
    result.first
  end

  def get_tvoc_inceptive_baseline
    result = send_command GET_TVOC_INCEPTIVE_BASELINE
    result.first
  end

  def set_tvoc_baseline baseline
    send_command SET_TVOC_BASELINE, baseline
  end

  def measure_iaq
    send_command MEASURE_IAQ
  end

  def send_command command, data = nil
    command, write_length, read_length, max_wait, format = command

    if read_length.zero? then
      write_command = 
        if write_length.zero? then
          command
        else
          data = Array(data).pack format
          data = apply_crc data
          command + data
        end

      I2C::Message.write @dev, write_command
    else
      I2C::Message.write @dev, command

      sleep max_wait / 1000.0

      message = I2C::Message.read @dev, read_length, command
      result = message.buffer.to_s read_length
      data = extract_data result
      data.unpack format
    end
  end
end

if $0 == __FILE__ then
  sgp30 = SGP30.new 1

  loop do
    puts "eCO₂: %5dppm tVOC: %5dppb" % sgp30.measure_iaq

    sleep 1
  end
end
