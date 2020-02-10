require "fiddle"
require "fiddle/import"

module I2C
  extend Fiddle::Importer

  class Error < RuntimeError; end

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
end

class I2C::Dev
  # uapi/linux/i2c-dev.h
  FOLLOWER = 0x0703
  RDWR     = 0x0707

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

  def transaction message
    data = I2C::ReadWriteIOCTLData.malloc

    data.messages = message
    data.count    = 1

    @i2c.ioctl RDWR, data.to_ptr
  end

  def write data
    @i2c.syswrite Array(data).pack "C*"
  end
end

class I2C::Message
  #
  # uapi/linux/i2c.h

  # i2c_msg
  WRITE = 0x0000 # M_WR
  READ  = 0x0001 # M_RD

  attr_writer :device

  def self.read device, data, length
    buffer = Fiddle::Pointer.malloc length
    buffer[0, data.bytesize] = data

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

