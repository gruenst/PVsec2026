import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
import digitalio
import adafruit_rfm9x
from math import sqrt
from digitalio import DigitalInOut, Direction
from adafruit_ads1x15.analog_in import AnalogIn

NODE = "volt_1"
NODENR = 12

# Define LED pin, turn it off
LED = digitalio.DigitalInOut(board.D5)
LED.direction = digitalio.Direction.OUTPUT
LED.value = False
# Create the ADC object using the I2C bus
i2c = busio.I2C(board.SCL, board.SDA)
ads = ADS.ADS1115(i2c, gain=2/3)

RADIO_FREQ_MHZ = 433.0  # Frequency of the radio in Mhz
chan = AnalogIn(ads, ADS.P0, ADS.P1) # ADC differential
V_OFFSET = 0.0  #offset

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

offset = ((abs(chan.voltage) * 2.0 )- 2.0) / 8.0 * 1500.0;  # read out offset when turned on
if ((offset > -5.0) and (offset < 5.0)):  # only use small offsets, otherwise there's an error
  V_OFFSET = -offset;  # offset as a voltage adjustment
# Initalization complete: turn LED on
LED.value = True
ads = ADS.ADS1115(i2c, gain=2/3)

while True:
    packet = rfm9x.receive(with_header=True,timeout=2)
    if packet is not None:
        try:
          packetText = str(packet, 'ascii')
        except:
          packetText = ""
        #print(packetText)
        if (packetText.find("ME") > -1):
            startTime = time.monotonic()   # start time after reception
            rfm9x.idle();  # enter radio idle mode
            if (abs(chan.voltage) < 1.95):  # signal always above 1V
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
            outText = NODE+';'
            if (j == 0):  # overshoot in all 10 voltage readings
                outText += "RANGE"+';'
            else:
                outText += "{:>4.2f}".format(((sumVoltage/j * 2.0 )- 2.0) / 8.0 * 1500.0 + V_OFFSET)+';'
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
              time.sleep(waitTime)   #start at 0.8s * NODENR after reception
            rfm9x.send(outText, node=NODENR)
