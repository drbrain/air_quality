# https://github.com/zinob/RPI_SGP30
#
# MIT License
#
# Copyright (c) 2018 Simon Albinsson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import smbus2
from smbus2 import SMBusWrapper, SMBus, i2c_msg
from collections import namedtuple
from functools import partial
from time import sleep, asctime, time
import json
from copy import copy
import os.path

DEVICE_BUS = 1
BASELINE_FILENAME = os.path.expanduser("~/.sgp30_config_data.txt")

class _cmds():
    """container class for mapping between human readable names and the command values used by the sgp"""
    SGP30Cmd     = namedtuple("SGP30Cmd", ["commands", "replylen", "waittime"])
    IAQ_INIT     = SGP30Cmd([0x20, 0x03], 0, 10)
    IAQ_MEASURE  = SGP30Cmd([0x20, 0x08], 6, 12)
    GET_BASELINE = SGP30Cmd([0x20, 0x15], 6, 120)
    SET_BASELINE = SGP30Cmd([0x20, 0x1e], 0, 10)
    SET_HUMIDITY = SGP30Cmd([0x20, 0x61], 0, 10)
    IAQ_SELFTEST = SGP30Cmd([0x20, 0x32], 3, 520)
    GET_FEATURES = SGP30Cmd([0x20, 0x2f], 3, 3)
    GET_SERIAL   = SGP30Cmd([0x36, 0x82], 9, 10)

    @classmethod
    def new_set_baseline(cls, baseline_data):
        cmd = cls.SET_BASELINE
        return cls.SGP30Cmd(cmd.commands +baseline_data, cmd.replylen, cmd.waittime)

class SGP30():
    def __init__(self,
                 bus,
                 device_address=0x58,
                 baseline_filename=BASELINE_FILENAME):
        self._bus = bus
        self._device_addr = device_address
        self._start_time = time()
        self._last_save_time = time()
        self._baseline_filename = baseline_filename

    def _raw_validate_crc(s, r):
        a = list(zip(r[0::3], r[1::3]))
        crc = r[2::3] == [Crc8().hash(i) for i in a ]

        return crc, a

    def read_write(self, cmd):
        write = i2c_msg.write(self._device_addr, cmd.commands)

        if cmd.replylen <= 0 :
           self._bus.i2c_rdwr(write)
        else:
            read = i2c_msg.read(self._device_addr, cmd.replylen)
            self._bus.i2c_rdwr(write) 

            sleep(cmd.waittime/1000.0)

            self._bus.i2c_rdwr(read)
            r = list(read)

            crc_ok, a = self._raw_validate_crc(r)
            answer = [i<<8 | j for i, j in a]

            return answer

    def store_baseline(self):
        with open(self._baseline_filename, "w") as conf:
            baseline = self.read_write(_cmds.GET_BASELINE)

            if baseline.crc_ok == True:
                json.dump(baseline.raw, conf)
                return True
            else:
                #print("Ignoring baseline due to invalid CRC")
                return False

    def try_set_baseline(self):
        try:
            with open(self._baseline_filename, "r") as conf:
                conf = json.load(conf)
        except IOError:
            pass
        except ValueError:
            pass
        else:
            crc, _ = self._raw_validate_crc(conf)

            if len(conf) == 6 and crc == True:
                self.read_write(_cmds.new_set_baseline(conf))
                return True
            else:
                #print("Failed to load baseline, invalid data")
                return False

    def read_measurements(self):
        return self.read_write(_cmds.IAQ_MEASURE)

    def read_selftest(self):
        return self.read_write(_cmds.IAQ_SELFTEST)

    def read_serial(self):
        return self.read_write(_cmds.GET_SERIAL)

    def read_features(self):
        return self.read_write(_cmds.GET_FEATURES)

    def init_sgp(self):
        self.read_write(_cmds.IAQ_INIT)

class Crc8:
    def __init__(s):
        s.crc = 255

    def hash(s, int_list):
        for i in int_list:
            s.addVal(i)

        return s.crc

    def addVal(s, n):
        crc = s.crc

        for bit in range(0, 8):
            if ( n ^ crc ) & 0x80:
                crc = ( crc << 1 ) ^ 0x31
            else:
                crc = ( crc << 1 )

            n = n << 1

        s.crc = crc & 0xFF

        return s.crc

def main():
    with SMBusWrapper(1) as bus:
        sgp = SGP30(bus, baseline_filename=BASELINE_FILENAME+".TESTING")

        print("feature set: 0x{0:02x}".format(*sgp.read_features()))
        print("serial: 0x{0:04x}{1:04x}{2:04x}".format(*sgp.read_serial()))

        sgp.init_sgp()

        while(True):
            eCO2, tVOC = sgp.read_measurements()

            if eCO2 != 400 or tVOC != 0:
                break;

            sleep(1.0)

        while(True):
            eCO2, tVOC = sgp.read_measurements()
            print("eCO₂: {} tVOC: {}".format(eCO2, tVOC))

            sleep(1.0)

    bus.close()

if __name__ == "__main__":
    main()
