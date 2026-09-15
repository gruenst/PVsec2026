# Current Clamp
resources for making a PCB for enhancing/hacking a commercially available DC current clamp (see type information) with LoRa and programming functionality. Here's a list of (probably identical) OEM products, only the third one has been used so far: <img width="701" height="293" alt="ClampManufacturers" src="https://github.com/user-attachments/assets/2d73181e-788e-4809-97b9-ddc36042c40c" />

The board is based on the Adafruit "Itsybitsy M4 express" for Circuitpython, as this gives in-field programming capability (changing the current clamp number) with any USB computer. The PCB fits nicely underneath the existing PCB.
As an antenna, any flexible and solderable antenna for 433MHz works, also simple wire or spring antennas.
I recommend this one: https://ctrfantennasinc.com/flex-pcb-433mhz-lora-antenna/

Node numbers are 1-10 for the clamps, and 11-13 for the additional satellite systems (irradiance+temperature, voltage, repeater).

Instead of a standard 9V battery, a modified Li-based battery could be used and connected to the PCB for charging purpose.
Alternatively, add another battery or power bank for longer usage times.
