See my page http://alyer.frihost.net/thrsensor.htm for project details.

The firmware for ATMEL AVR ATtiny2313L MCU, TLP434 transmitter and SHT11 temp/humidity sensor.

The whole device works as two THN128 Oregon Scientific sensors (one is sending humidity value at channel 1, the other - sending temperature value at channel 2)

Main MCU (aka ATtiny 2313) reads temperature/humidity values from Sensirion SHT sensor (SPI chanel), encoded them to Oregon Scientific protocol and then sends to the air.

The measurements can me viewed at compitible Oregon Scientific weather stations.