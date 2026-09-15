# irradiance sensor with module temperature acquisition

Modification/hack of standard M&T irradiance sensors with an own-made PCB, and battery for independent operation.
As the current clamps, this is base don the Adafruit Itsybitsy M4 Express, so the code can be adapted/changed in the field with any computer (mounts as USB stick).
There is an USB B and C adapter for charging and programming.
There are soldering ports for adding a power switch, and adding an indicator LED. Alternatively, use a LED button.
PT temperature acquisition is done with a simple resistor bridge, as usually attachment of field sensors are by far the higher source of uncertainty than wire resistances.
But feel free to add a proper 4wire PT reading circuit (e.g. MAX31865), which was tested in yet another implementation.
As PT sensors, I recommend foil based ones with temperature conductive pastes. But whichever sensor, there is a lot to learn using them.
