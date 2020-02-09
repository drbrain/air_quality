module I2C
  class Error < RuntimeError; end
end

class I2C::Dev
  # linux/i2c.h
  FOLLOWER = 0x0703

  class NoSuchBus < I2C::Error
    def initialize bus
      super "No device /dev/i2c-#{bus} found"
    end
  end

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

  def write data
    @i2c.syswrite data.pack "C*"
  end
end
