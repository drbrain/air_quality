
#
# Library for Grove - PM2.5 PM10 detect sensor (HM3301)
#
## License
#
# The MIT License (MIT)
#
# Copyright (C) 2018  Seeed Technology Co.,Ltd.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

from smbus2 import SMBus, i2c_msg
import time

HM3301_DEFAULT_I2C_ADDR = 0x40
HM3301_USE_I2C = 0x88
HM3301_DATA_FRAME_SIZE = 29

class HM3301:
    class Error(Exception):
        pass

    def __init__(self, bus=1):
        self.sensor_number = 0

        # Standard particulate matter concentrations in µg/m³
        self.PM_1_0_standard_particulate = 0
        self.PM_2_5_standard_particulate = 0
        self.PM_10_standard_particulate  = 0

        # Atmospheric environment concentration in µg/m³
        self.PM_1_0_atmospheric_environment = 0
        self.PM_2_5_atmospheric_environment = 0
        self.PM_10_atmospheric_environment  = 0

        # Number of particles in 1 liter of air with diameter in µm above
        # I think these are returned on HM-3X02
        self.particles_0_3 = 0
        self.particles_0_5 = 0
        self.particles_1_0 = 0
        self.particles_2_5 = 0
        self.particles_5_0 = 0
        self.particles_10  = 0

        self.bus = SMBus(bus)
        use_i2c = i2c_msg.write(HM3301_DEFAULT_I2C_ADDR, [HM3301_USE_I2C])
        self.bus.i2c_rdwr(use_i2c)

    def atmospheric_environment(self):
        return [
            self.PM_1_0_atmospheric_environment,
            self.PM_2_5_atmospheric_environment,
            self.PM_10_atmospheric_environment
        ]

    def read_data(self):
        msg = i2c_msg.read(HM3301_DEFAULT_I2C_ADDR, HM3301_DATA_FRAME_SIZE)

        self.bus.i2c_rdwr(msg)

        data = list(msg)

        if not hm3301.check_crc(data):
            raise self.Error("CRC check failed")

        self.sensor_number = data[2] << 8 | data[3]

        self.PM_1_0_standard_particulate = data[4] << 8 | data[5]
        self.PM_2_5_standard_particulate = data[6] << 8 | data[7]
        self.PM_10_standard_particulate  = data[8] << 8 | data[9]

        self.PM_1_0_atmospheric_environment = data[10] << 8 | data[11]
        self.PM_2_5_atmospheric_environment = data[12] << 8 | data[13]
        self.PM_10_atmospheric_environment  = data[14] << 8 | data[15]

        self.particles_0_3 = data[16] << 8 | data[17]
        self.particles_0_5 = data[18] << 8 | data[19]
        self.particles_1_0 = data[20] << 8 | data[21]
        self.particles_2_5 = data[22] << 8 | data[23]
        self.particles_5_0 = data[24] << 8 | data[25]
        self.particles_10 =  data[26] << 8 | data[27]

    def check_crc(self,data):
        sum = 0

        for i in range(HM3301_DATA_FRAME_SIZE-1):
            sum += data[i]

        sum = sum & 0xff

        return sum == data[28]

    def particle_counts(self):
        return [
            self.particles_0_3,
            self.particles_0_5,
            self.particles_1_0,
            self.particles_2_5,
            self.particles_5_0,
            self.particles_10
        ]

    def show_data(self):
        print("Standard particulate matter PM 1.0: {} PM 2.5: {} PM 10: {}".format(*self.standard_particulates()))
        print("Atmospheric environment     PM 1.0: {} PM 2.5: {} PM 10: {}".format(*self.atmospheric_environment()))
        print("")

    def standard_particulates(self):
        return [
            self.PM_1_0_standard_particulate,
            self.PM_2_5_standard_particulate,
            self.PM_10_standard_particulate
        ]

if __name__ == '__main__':
    hm3301 = HM3301()

    time.sleep(.1)

    hm3301.read_data()
    print("sensor number: {}".format(hm3301.sensor_number))

    while True:
        data = hm3301.read_data()

        hm3301.show_data()

        # minimum refresh time
        time.sleep(1)
