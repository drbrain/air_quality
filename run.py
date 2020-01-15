from BME280 import BME280
from SGP30 import SGP30
import datetime
import math
import signal
import smbus2
from smbus2 import SMBus
import time

def absolute_humidity(temperature, relative_humidity):
    """https://carnotcycle.wordpress.com/2012/08/04/how-to-convert-relative-humidity-to-absolute-humidity/"""
    """https://esphome.io/cookbook/bme280_environment.html"""
    t     = temperature
    r_hum = relative_humidity

    a_hum = (6.112 * math.pow(math.e, (17.67 * t) / (t + 243.5)) * r_hum * 18.01534) / ((273.15 + t) * 8.31447215)

    return a_hum

def handler(signal, frame):
    exit(0)

signal.signal(signal.SIGINT, handler)

bme280 = BME280(address=0x76)

sgp30 = SGP30(SMBus(1))
sgp30.init_sgp()

while(True):
    now = datetime.datetime.now().isoformat(timespec='seconds')

    temp  = bme280.read_temperature()
    pres  = bme280.read_pressure() / 1000
    r_hum = bme280.read_humidity()

    a_hum = absolute_humidity(temp, r_hum)

    print("{0} {1:0.2f}℃ {2:0.2f}hPa {3:0.3f}%RH".format(now, temp, pres, hum))

    eCO2, tVOC = sgp30.read_measurements()
    print("eCO₂: {}ppm tVOC: {}ppb".format(eCO2, tVOC))

    time.sleep(1)

