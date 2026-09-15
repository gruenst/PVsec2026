import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
import digitalio
import adafruit_rfm9x
from math import sqrt
from digitalio import DigitalInOut, Direction
from adafruit_ads1x15.analog_in import AnalogIn

# Create the ADC object using the I2C bus
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c, gain=2/3)

RADIO_FREQ_MHZ = 433.0  # Frequency of the radio in Mhz
setVolt = DigitalInOut(board.A2)
setVolt.direction = Direction.OUTPUT
chanVolt = AnalogIn(ads, ADS.P3) # Voltage reading
chanPt = AnalogIn(ads, ADS.P2) # PT1000 reading
setVolt.value = False  # no PT reading

NODE = "irr_1"
NODENR = 11

# Define pins connected to the chip
CS = digitalio.DigitalInOut(board.A4)
RESET = digitalio.DigitalInOut(board.A3)
# Initialize SPI bus.
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)


# Initialze RFM radio
rfm9x = adafruit_rfm9x.RFM9x(spi, CS, RESET, RADIO_FREQ_MHZ)
rfm9x.tx_power = 23
rfm9x.signal_bandwidth = 62500
rfm9x.coding_rate = 8
rfm9x.spreading_factor = 9
rfm9x.enable_crc = True

while True:
    ads = ADS.ADS1115(i2c, gain=2/3)
    packet = rfm9x.receive()
    if packet is not None:
        try:
          packetText = str(packet, 'ascii')
        except:
          packetText = ""
        print(packetText)
        print(packetText)
        if (packetText.find("ME") > -1):
            startTime = time.monotonic()   # start time after reception
            rfm9x.idle();  # enter radio idle mode
            chan = AnalogIn(ads, ADS.P0, ADS.P1)
            if (abs(chan.voltage) < 0.225):
              ads = ADS.ADS1115(i2c, gain=16)
            elif (abs(chan.voltage) < 0.45):
              ads = ADS.ADS1115(i2c, gain=8)
            elif (abs(chan.voltage) < 0.975):
              ads = ADS.ADS1115(i2c, gain=4)
            elif (abs(chan.voltage) < 1.95):
              ads = ADS.ADS1115(i2c, gain=2)
            elif (abs(chan.voltage) < 3.975):
              ads = ADS.ADS1115(i2c, gain=1)
            j = 0
            sumVoltage = 0.0
            for i in range(0, 10):
                chan = AnalogIn(ads, ADS.P0, ADS.P1)
                if (chan.value < 0xFFFA):
                    sumVoltage += chan.voltage
                    #print(sumVoltage)
                    j += 1
            sumVoltage = abs(sumVoltage)
            ads = ADS.ADS1115(i2c, gain=1)
            setVolt.value = True # apply about 5V
            voltH = chanVolt.voltage
            ads = ADS.ADS1115(i2c, gain=4)  # voltage < 1V
            voltR = chanPt.voltage # PT1000 reading
            setVolt.value = False # prevent heating up
            try:
              if (voltR == 0.0):
                resPt = 0
              else:
                resPt = 400.0 * voltH / voltR - 400.0
              degC = 3.9083E-3*3.9083E-3+(4*5.775E-7)
              degC -= 4 * 5.775E-7 * resPt/1000.0
              degC = - (sqrt(degC) - 3.9083E-3) / (2*5.775E-7)
            except:
              degC = -999
            outText = NODE+';'
            if (j == 0):  # overshoot in all 10 voltage readings
                outText += "RANGE"+';'
            else:
                outText += "{:>4.2f}".format(sumVoltage/j*1000.0)+';'
            outText += "{:>3.1f}".format(degC) + ';'
            outText += "{:>3.1f}".format(degC) + ";"
            clampText = packetText[packetText.find("ME")+2]
            numClamps = 5
            if (clampText == '0'):
              numClamps = 10
            else:
              numClamps = int(clampText);
            waitTime = ((NODENR - 10 + numClamps) * 0.8) - (time.monotonic()-startTime)
            if (ord(packetText[1]) == 13): #message from repeater, ~300 ms delayed
              waitTime -= 0.35
            if (waitTime > 0):
              time.sleep(waitTime)   #start at 2.2s after reception
            rfm9x.send(outText, node=NODENR)
