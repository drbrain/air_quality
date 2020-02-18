require "fiddle"
require "fiddle/import"

module I2C
  extend Fiddle::Importer

  class Error < RuntimeError; end

  SMBUS_READ  = 1
  SMBUS_WRITE = 0

  SMBUS_QUICK = 0
  SMBUS_BYTE  = 1

  IOCTLData = struct [
    "unsigned short read_write",
    "unsigned short command",
    "unsigned long  size",
    "void           *data",
  ]

  Message = struct [
    "unsigned short address",
    "unsigned short flags",
    "unsigned short length",
    "char           *buffer",
  ]

  ReadWriteIOCTLData = struct [
    "void          *messages",
    "unsigned long count",
  ]

  SMBusData = union [
    "unsigned char  byte",
    "unsigned short word",
    "unsigned char  *block",
  ]

  def self.scan bus, first: 0x03, last: 0x77
    return enum_for __method__, bus, first: first, last: last unless
      block_given?

    (first..last).map do |address|
      dev = I2C::Dev.new bus, address

      case address
      when 0x30..0x37,
           0x50..0x5F then
        dev.read_byte
      else
        dev.write_quick 0
      end

      yield dev
    rescue Errno::EREMOTEIO
    end
  end
end

class I2C::Dev
  # uapi/linux/i2c-dev.h
  FOLLOWER = 0x0703
  RDWR     = 0x0707
  SMBUS    = 0x0720

  class NoSuchBus < I2C::Error
    def initialize bus
      super "No device /dev/i2c-#{bus} found"
    end
  end

  attr_reader :address

  def initialize bus, address
    @bus     = bus
    @address = address

    path = "/dev/i2c-#{bus}"

    begin
      @i2c = File.open path, "r+"
    rescue SystemCallError
      raise NoSuchBus, @bus
    end

    @i2c.ioctl FOLLOWER, @address
  end

  def read register, length
    @i2c.syswrite register.chr if register
    @i2c.sysread length
  end

  def read_byte
    data = I2C::SMBusData.malloc

    smbus_access I2C::SMBUS_READ, 0, I2C::SMBUS_BYTE, data

    data.byte & 0xFF
  end

  def read_S8 register
    value = read register, 1

    value.unpack("c").first
  end

  def read_S16 register
    value = read register, 2
    value.unpack("s<").first
  end

  def read_U8 register
    value = read register, 1
    value.unpack("C").first
  end

  def read_U16 register
    value = read register, 2
    value.unpack("S<").first
  end

  def smbus_access read_write, command, size, data
    args = I2C::IOCTLData.malloc

    args.read_write = read_write
    args.command    = command
    args.size       = size
    args.data       = data

    err = @i2c.ioctl SMBUS, args.to_ptr
  end

  def transaction message
    data = I2C::ReadWriteIOCTLData.malloc

    data.messages = message
    data.count    = 1

    @i2c.ioctl RDWR, data.to_ptr
  end

  def write data
    @i2c.syswrite Array(data).pack "C*"
  end

  def write_quick value
    smbus_access value, 0, I2C::SMBUS_QUICK, nil
  end
end

class I2C::Message
  #
  # uapi/linux/i2c.h

  # i2c_msg
  WRITE = 0x0000 # M_WR
  READ  = 0x0001 # M_RD

  attr_writer :device

  def self.read device, length, data = nil
    buffer = Fiddle::Pointer.malloc length
    buffer[0, data.bytesize] = data if data

    message = malloc

    message.address = device.address
    message.flags   = READ
    message.length  = length
    message.buffer  = buffer

    device.transaction message
    message
  end

  def self.write device, data
    buffer = Fiddle::Pointer.malloc data.bytesize
    buffer[0, data.bytesize] = data

    message = malloc

    message.address = device.address
    message.flags   = WRITE
    message.length  = data.bytesize
    message.buffer  = buffer

    device.transaction message
    message
  end
end

