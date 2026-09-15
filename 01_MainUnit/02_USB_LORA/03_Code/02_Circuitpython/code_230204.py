# AA-central unit, CircuitPython version
# function: replaces the M5stack central node. Receives measurement commands via USB serial
# from the Flutter GUI, sends "MEn"/"CLn" via LoRa to the satellites, collects the answers
# (with the same waiting times as the original code) and sends the result string back via USB serial.
# No display, no buttons, no SD card, no save - saving is handled locally in the Flutter app.

import time
import board
import busio
import digitalio
import adafruit_rfm9x
import usb_cdc

# ------- Global variables, drivers and definitions -----------
RADIO_FREQ_MHZ = 433.0
NUM_SATELLITES = 13   # number of satellite devices, followed by the keywords for each one
satellites = ["clamp_1", "clamp_2", "clamp_3", "clamp_4", "clamp_5", "clamp_6", "clamp_7",
              "clamp_8", "clamp_9", "clamp_0", "irr_1", "volt_1", "irr_2"]
answers = [""] * NUM_SATELLITES    # the answer strings with the measurement variables
NumClamps = 5                      # number of clamps
StringID = ""                      # string identifier, sent along with the command
ClampsOnly = False
TriggerMeasure = False

serial = usb_cdc.console           # serial link to the Flutter GUI

CS = digitalio.DigitalInOut(board.A4)
RESET = digitalio.DigitalInOut(board.A3)
spi = busio.SPI(board.SCK, MOSI=board.MOSI, MISO=board.MISO)

rfm9x = adafruit_rfm9x.RFM9x(spi, CS, RESET, RADIO_FREQ_MHZ)
rfm9x.tx_power = 23               # transmission power: 23dB
rfm9x.signal_bandwidth = 62500
rfm9x.coding_rate = 8
rfm9x.spreading_factor = 9
rfm9x.enable_crc = True
#---END Global variables, drivers and definitions -----------

def read_serial(serial):
    available = serial.in_waiting
    text = ""
    while available:
        raw = serial.read(available)
        text += str(raw, "utf-8")
        available = serial.in_waiting
    return text

def process_command(message):    # parse command from the Flutter GUI (terminated by newline)
    global NumClamps, StringID, ClampsOnly, TriggerMeasure
    if ("MEASURE_" in message) or ("CLAMPS_" in message):   # used for starting the measurement
        ClampsOnly = ("CLAMPS_" in message)
        digits = message[message.index("_") + 1 : message.index(";")]   # clamp count between "_" and ";"
        NumClamps = int(digits) if digits.isdigit() else 5
        if NumClamps == 0: NumClamps = 10    # 0 stands for 10
        StringID = message[message.index(";") + 1:].strip()
        TriggerMeasure = True

def measure():                  # full measurement sequence: LoRa command out, answers in, result out
    global TriggerMeasure
    TriggerMeasure = False
    #-----------construct measurement command: "CL" for clamps only, or "ME" for all satellites------
    numClamps = "0" if NumClamps == 10 else str(NumClamps)
    command = ("CL" if ClampsOnly else "ME") + numClamps

    #-----------LoRa sequence, sending command to satellites -------------------
    rfm9x.send(bytes(command, "ascii"), destination=0, node=0, identifier=0, flags=0)
    startTime = time.monotonic()
    print("measuring...", flush=True)

    for i in range(NUM_SATELLITES): answers[i] = ""   # clear answers, in case of reception error
    if ClampsOnly: maxTime = (NumClamps + 1) * 0.8          # same waiting times as original code, in seconds
    else:          maxTime = (NUM_SATELLITES - 10 + NumClamps + 2) * 0.8

    received = 0
    while (time.monotonic() - startTime < maxTime):   # read responses from satellites
        packet = rfm9x.receive(timeout=0.05)
        if packet is None: continue
        try: message = str(packet, "ascii")
        except: continue                              # skip gibberish / CRC failures
        for i in range(NUM_SATELLITES):
            if message.startswith(satellites[i]):
                #---------special part for repeater unit! save repeated messages---------
                if message.startswith("irr_2"):
                    while "#" in message:             # read out all extra messages
                        repeatedAnswer = message[message.rindex("#") + 1:]
                        for j in range(NUM_SATELLITES):
                            if repeatedAnswer.startswith(satellites[j]):
                                answers[j] = repeatedAnswer[repeatedAnswer.index(";") + 1 : repeatedAnswer.rindex(";") + 1]
                                break
                        message = message[:message.rindex("#")]   # strip extra content from original message
                    startTime = 0   # last message of repeater unit, breaks reception loop
                #---------END special part for repeater unit---------
                if answers[i] == "":          # only save one result per satellite
                    answers[i] = message[message.index(";") + 1 : message.rindex(";") + 1]  # strip identifier
                    received += 1
                break
    #-----------END LoRa sequence, getting measurement data from satellites -------------------

    #-----------send results to Flutter GUI via USB serial -------------------
    htmlString = "result;"            # prefix expected by the LoraModel parser in the Flutter app
    htmlString += "string;" + StringID + "|"
    for i in range(NUM_SATELLITES):
        htmlString += satellites[i] + ";"
        if len(answers[i]) < 1:
            if satellites[i] == "irr_1": htmlString += "|tmod_1;|tmod_2;|"
            else: htmlString += "|"
        else:
            if satellites[i] == "irr_1":   # irr_1 answer carries 3 values: irr;temp1;temp2;
                parts = answers[i].split(";")
                htmlString += parts[0] + "|tmod_1;" + (parts[1] if len(parts) > 1 else "") + "|tmod_2;" + (parts[2] if len(parts) > 2 else "") + "|"
            else:
                htmlString += answers[i][:answers[i].index(";")] + "|"
    print(htmlString, flush=True)     # print goes to usb_cdc.console; terminated with newline for the Flutter transaction parser
    #-----------END send results to client -------------------

# --------------- Main Loop ---------------
inText = ""
print("central unit ready", flush=True)

while True:
    try:
        inText += read_serial(serial)
        if "\n" in inText:                       # process complete commands only
            line, inText = inText.split("\n", 1)
            if line.strip():
                process_command(line.strip())
        if TriggerMeasure:
            measure()
    except Exception as e:
        print("error: " + str(e), flush=True)
        inText = ""
