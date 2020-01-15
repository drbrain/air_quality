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
from smbus2 import SMBus, i2c_msg
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
    SGP30Cmd = namedtuple("SGP30Cmd", ["commands", "replylen", "waittime"])

    # SGP30 datasheet Version 0.92 – April 2019 Table 10, Feature set 0x22
    IAQ_INIT                    = SGP30Cmd([0x20, 0x03], 0, 10)
    MEASURE_IAQ                 = SGP30Cmd([0x20, 0x08], 6, 12)
    GET_IAQ_BASELINE            = SGP30Cmd([0x20, 0x15], 6, 10)
    SET_IAQ_BASELINE            = SGP30Cmd([0x20, 0x1e], 0, 10)
    SET_ABSOLUTE_HUMIDITY       = SGP30Cmd([0x20, 0x61], 0, 10)
    MEASURE_TEST                = SGP30Cmd([0x20, 0x32], 3, 220)
    GET_FEATURE_SET             = SGP30Cmd([0x20, 0x2f], 3, 10)
    MEASURE_RAW                 = SGP30Cmd([0x20, 0x50], 6, 25)
    GET_TVOC_INCEPTIVE_BASELINE = SGP30Cmd([0x20, 0xb3], 3, 10)
    SET_TVOC_BASELINE           = SGP30Cmd([0x20, 0x77], 0, 10)
    GET_SERIAL_ID               = SGP30Cmd([0x36, 0x82], 9, 10)

    @classmethod
    def new_SET_IAQ_BASELINE(cls, data_with_crc):
        cmd = cls.SET_IAQ_BASELINE

        send = cmd.commands + data_with_crc

        return cls.SGP30Cmd(send, cmd.replylen, cmd.waittime)

    @classmethod
    def new_SET_TVOC_BASELINE(cls, data_with_crc):
        cmd = cls.SET_TVOC_BASELINE

        send = cmd.commands + data_with_crc

        return cls.SGP30Cmd(send, cmd.replylen, cmd.waittime)

class SGP30():
    def __init__(self,
                 bus,
                 device_address=0x58):
        self._bus = bus
        self._device_addr = device_address

        self.iaq_init()

        if self.read_features() >= 0x22:
            tvoc_baseline = self.read_tvoc_inceptive_baseline()
            self.write_tvoc_baseline(tvoc_baseline)

    def _generate_crc(self, data):
        def writable_value_with_crc(value):
            msb = value >> 8
            lsb = value & 0xFF
            crc = Crc8().hash([msb, lsb])

            return [msb, lsb, crc]

        data_with_crc = list(map(writable_value_with_crc, data))
        data_with_crc = [item for sublist in data_with_crc for item in sublist]

        return data_with_crc

    def _validate_crc(s, r):
        a = list(zip(r[0::3], r[1::3]))
        crc = r[2::3] == [Crc8().hash(i) for i in a ]

        return crc, a

    def _read_write(self, cmd):
        write = i2c_msg.write(self._device_addr, cmd.commands)

        if cmd.replylen <= 0 :
           self._bus.i2c_rdwr(write)
        else:
            read = i2c_msg.read(self._device_addr, cmd.replylen)
            self._bus.i2c_rdwr(write) 

            sleep(cmd.waittime/1000.0)

            self._bus.i2c_rdwr(read)
            r = list(read)

            crc_ok, a = self._validate_crc(r)
            answer = [i<<8 | j for i, j in a]

            return answer

    def read_tvoc_inceptive_baseline(self):
        return self._read_write(_cmds.GET_TVOC_INCEPTIVE_BASELINE)

    def write_tvoc_baseline(self, baseline):
        baseline_with_crc = self._generate_crc(baseline)

        self._read_write(_cmds.new_SET_TVOC_BASELINE(baseline_with_crc))

    def read_iaq_baseline(self):
        return self._read_write(_cmds.GET_IAQ_BASELINE)

    def write_iaq_baseline(self, baseline):
        baseline_with_crc = self._generate_crc(baseline)

        self._read_write(_cmds.new_SET_IAQ_BASELINE(baseline_with_crc))

    def read_measurements(self):
        return self._read_write(_cmds.MEASURE_IAQ)

    def read_selftest(self):
        return self._read_write(_cmds.MEASURE_TEST)

    def read_serial(self):
        return self._read_write(_cmds.GET_SERIAL_ID)

    def read_features(self):
        return self._read_write(_cmds.GET_FEATURE_SET)[0]

    def iaq_init(self):
        self._read_write(_cmds.IAQ_INIT)

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
    with SMBus(1) as bus:
        sgp = SGP30(bus)

        print("feature set: 0x{0:02x}".format(*sgp.read_features()))
        print("serial: 0x{0:04x}{1:04x}{2:04x}".format(*sgp.read_serial()))

        while(True):
            eCO2, tVOC = sgp.read_measurements()
            print("eCO₂: {} tVOC: {}".format(eCO2, tVOC))

            sleep(1.0)

if __name__ == "__main__":
    main()
