# Open Source Hardware for Mobile String Power Acquisition of Solar Parks
Circuitpython and C++ based measurement system for Photovoltaic Installations. Up to 10 current clamps can be integrated, additional voltage, current and module temperature acquisition.


## Purpose
 * Open-source enhancements of publicly available hardware resources with LoRa radio for long range sensor data acquisition capability (no mesh network).
 * Complete system for measuring solar parks with flawed or without string monitoring
 * Versatile alternative to IV curve acquisition systems specifically for systems without single string accessibility - adapt to your own liking.

## Usage
 * Plug device in, opens up as USB stick (circuitpython)
 * Open .html file in Web Serial API compatible browser (Chrome, Edge, Opera; see https://developer.mozilla.org/en-US/docs/Web/API/Serial)
 * Use browser as GUI, connect to device and send/receive commands to/from device via serial interface
 * commands will be forwarded via LoRa RFM98W radio chip to remote device
 
## Content
 - Descriptions:    Short descriptions of each system with pictures 
 - PCBs, BOM:       EAGLE Cad PCB files, list of components
 - Housing:         3D STP files for 3D printing
 - Circuit Python:  Circuitpython .uf2, device code
 - GUI:             code.py for device, .html code with .js elements for GUI control, Arduino C++ code, web Serial or WLAN websocket control
 - bootloader:      Atmel SAMD bootloader for JLink
(https://learn.adafruit.com/adafruit-feather-m0-express-designed-for-circuit-py$


 
## Manual
 - Make PCB, solder components
 - flash bootloader using .bin file, e.g. via JLink, see https://learn.adafruit.com/how-to-program-samd-bootloaders
 - mount device via usb, put into bootloader mode, upload circuitpython .uf2 file
 - copy circuitpython8 lib elements to /lib directory on device
 - put code.py to device
 - upload .html file to device, adjust accordingly
 enjoy!
 
[Grn.Solar](https://www.grn.solar)
 
 Big shoutouts to [Adafruit](https://www.adafruit.com "Adafruit rocks") and Flaticon.
