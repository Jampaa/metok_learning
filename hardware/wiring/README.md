# Wiring Notes

Reference only — verify against your specific ESP32 board's pinout silkscreen.

## PN532 (SPI mode)

| PN532 | ESP32 |
|---|---|
| VCC | 3.3V |
| GND | GND |
| SCK | GPIO18 |
| MISO | GPIO19 |
| MOSI | GPIO23 |
| SS | GPIO5 |

## MAX98357A (I2S amp) -> speaker

| MAX98357A | ESP32 |
|---|---|
| VIN | 5V |
| GND | GND |
| BCLK | GPIO26 |
| LRC | GPIO25 |
| DIN | GPIO22 |
| + / - | Speaker terminals |

Keep the PN532 antenna area clear of the speaker magnet — magnets can
interfere with NFC read range.
