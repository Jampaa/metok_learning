# Hardware (ESP32 NFC Toy)

See `hardware/esp32-nfc-toy/esp32-nfc-toy.ino` and its own README for wiring
and library details. Summary:

```
NFC sticker tapped -> PN532 reads UID -> ESP32 looks up UID locally
    -> plays the matching pre-loaded MP3 from SPIFFS -> speaker
```

**Deliberately no network / online TTS on the device** (Section 28) — the
physical demo must work with zero connectivity dependency. The ESP32
*optionally* POSTs to `/api/nfc-event` afterward if Wi-Fi is available, purely
for the analytics dashboard; it never blocks on that call.

## Demo-day risk

Soldering/wiring issues are the single highest-risk failure point in the
whole golden demo — everything else is software you fully control. **Always
have the web fallback ready**: `frontend/src/features/nfc/NfcScreen.tsx`'s
"Simulate Tap" buttons reproduce the same word-card-plus-audio result without
the toy. If the hardware misbehaves on stage, pivot to that without missing
a beat.

## Bill of materials

- ESP32 dev board
- PN532 NFC/RFID reader (SPI or I2C)
- Small speaker
- MAX98357A I2S amplifier (optional but recommended — cleaner audio than a
  raw ESP32 DAC pin)
- NFC stickers (NTAG213 or similar) — one per vocabulary word

## Sticker -> word mapping

Edit `TAG_MAP` at the top of the `.ino` file with the UID printed to Serial
when you first tap each sticker. This mirrors the `nfc_tags/{tagUid}`
Firestore collection (`docs/database.md`) but lives locally on the device so
the demo has zero dependency on connectivity.
