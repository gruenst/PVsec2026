# Radio signal "ME"ASURE or "CL"AMPS triggers 10x ADC measurements (averaged)
import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
import digitalio
import adafruit_rfm9x
from adafruit_ads1x15.analog_in import AnalogIn
RADIO_FREQ_MHZ = 433.0  # Frequency of the radio in Mhz. Must match your
i2c = busio.I2C(board.SCL, board.SDA)

# clamp 10 -> clamp_0  
CLAMP = "clamp_0"
NODENR = int(CLAMP[-1])
if NODENR == 0:
  NODENR = 10

# Define pins connected to the chip
CS = digitalio.DigitalInOut(board.A4)
RESET = digitalio.DigitalInOut(board.A3)
# Initialize SPI bus.
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)
# Create the ADC object using the I2C bus
ads = ADS.ADS1115(i2c, gain=2/3)

# Initialze RFM radio
rfm9x = adafruit_rfm9x.RFM9x(spi, CS, RESET, RADIO_FREQ_MHZ)
rfm9x.tx_power = 23
rfm9x.signal_bandwidth = 62500
rfm9x.coding_rate = 8
rfm9x.spreading_factor = 9
rfm9x.enable_crc = True
# ADC differential reading between P0 and P1
chan = AnalogIn(ads, ADS.P0, ADS.P1)

while True:
    ads = ADS.ADS1115(i2c, gain=2/3)
    packet = rfm9x.receive(with_header=True,timeout=2)
    if packet is not None:
        try:
          packetText = str(packet, 'ascii')
        except:
          packetText = ""
        print(packetText)
        if ((packetText.find("ME") > -1) or (packetText.find("CL") > -1)):
            startTime = time.monotonic()   # start time after reception
            rfm9x.idle();  # enter radio idle mode
            firstReading = abs(chan.voltage)
            if (firstReading < 0.225):
              ads = ADS.ADS1115(i2c, gain=16)
            elif (firstReading < 0.45):
              ads = ADS.ADS1115(i2c, gain=8)
            elif (firstReading < 0.975):
              ads = ADS.ADS1115(i2c, gain=4)
            elif (firstReading < 1.95):
              ads = ADS.ADS1115(i2c, gain=2)
            elif (firstReading < 3.975):
              ads = ADS.ADS1115(i2c, gain=1)
            j = 0
            reference = abs(chan.voltage)
            refMin = 0.95 * reference   # for outlier identification
            refMax = 1.05 * reference   # for outlier identification
            sumVoltage = 0
            for i in range(0, 10):
              readVolt = abs(chan.voltage)
              readValue = chan.value
              if ((readValue < 0xFFFA) and (readVolt < refMax) and (readVolt > refMin)):
                sumVoltage += readVolt
                j += 1
            outText = CLAMP+';'  # prepare output text
            if (j == 0):  # overshoot in all 10 voltage readings
              outText += "ERROR"+';'
            else:
              outText += "{:>5.4f}".format(sumVoltage/j*10.0)+';'
            waitTime = NODENR * 0.8  # 0.8s for each clamp before, 0.8s initially for repeater
            waitTime += startTime - time.monotonic()
            if (ord(packetText[1]) == 13): #message from repeater, ~350 ms delayed
              waitTime -= 0.35
            if (waitTime > 0):
              time.sleep(waitTime)
            rfm9x.send(outText, node=NODENR)

