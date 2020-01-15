# Derived from: https://github.com/ControlEverythingCommunity/ADC121C021/
#
# Which was distributed with a free-will license.
# Use it any way you want, profit or free, provided it fits in the licenses of
# its associated works.

class ADC121C021():
    class Error(Exception):
        pass

    REG_RESULT             = 0x00
    REG_ALERT_STATUS       = 0x01
    REG_CONFIG             = 0x02
    REG_ALERT_LIMIT_UNDER  = 0x03
    REG_ALERT_LIMIT_OVER   = 0x04
    REG_LOWEST_CONVERSION  = 0x05
    REG_HIGHEST_CONVERSION = 0x06

    CONVERT_DISABLED = 0b000
    CONVERT_X_32     = 0b001
    CONVERT_X_64     = 0b010
    CONVERT_X_128    = 0b011
    CONVERT_X_256    = 0b100
    CONVERT_X_512    = 0b101
    CONVERT_X_1024   = 0b110
    CONVERT_X_2048   = 0b111

    _CONVERT_VALUES = [
        CONVERT_DISABLED,
        CONVERT_X_32,
        CONVERT_X_64,
        CONVERT_X_128,
        CONVERT_X_256,
        CONVERT_X_512,
        CONVERT_X_1024,
        CONVERT_X_2048,
    ]

    def __init__(self,
                 bus,
                 address=0x50,
                 convert=CONVERT_X_32):
        self._bus = bus
        self._address = address

        self.set_config(convert)

    def set_config(self,
                   convert,
                   alert_hold=False,
                   alert_flag=False,
                   alert_pin=False,
                   polarity=False):
        if convert not in self._CONVERT_VALUES:
            raise Error("Unexpected convert value {0}".format(convert))

        config = convert << 5
        if alert_hold: config |= 1 << 4
        if alert_flag: config |= 1 << 3
        if alert_pin:  config |= 1 << 3
        if polarity:   config |= 1
        
        self._bus.write_byte_data(self._address, self.REG_CONFIG, config)

    def read_result(self):
        msb, lsb = self._bus.read_i2c_block_data(self._address, self.REG_RESULT, 2)

        alert_flag = 1 == (msb & 0x80)

        value = ((msb & 0xf0) << 8) | lsb

        return value, alert_flag

if __name__ == "__main__":
    import datetime
    import smbus2
    from smbus2 import SMBus
    import time

    with SMBus(1) as bus:
        adc = ADC121C021(bus)

        while(True):
            now = datetime.datetime.now().isoformat(timespec='seconds')

            value, alert = adc.read_result()

            print("{} value: {} alert: {}".format(now, value, alert))

            time.sleep(1.0)
