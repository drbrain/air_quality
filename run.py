from BME280 import BME280
import datetime
import signal
import time

def handler(signal, frame):
    exit(0)

signal.signal(signal.SIGINT, handler)

bme280 = BME280(address=0x76)

while(True):
    now = datetime.datetime.now().isoformat()

    temp = bme280.read_temperature()
    pres = bme280.read_pressure() / 1000
    hum  = bme280.read_humidity()

    print("{0} {1:0.2f}℃ {2:0.2f}hPa {3:0.3f}%RH".format(now, temp, pres, hum))

    time.sleep(1)

