# ESP32 NFC Toy

Reference firmware — see `docs/hardware.md` for the full write-up and the
"always keep the web fallback ready" demo-safety note.

## Flash it

1. Arduino IDE -> install the ESP32 board package + libraries listed at the
   top of `esp32-nfc-toy.ino`.
2. Wire per `hardware/wiring/`.
3. Upload the sketch, open Serial Monitor (115200 baud).
4. Tap each sticker once to learn its UID, fill in `TAG_MAP`, re-upload.
5. Use the ESP32 Sketch Data Upload tool to push the mp3 files referenced in
   `TAG_MAP` into SPIFFS.

## Getting the mp3 files

Generate them via the backend once Monlam is configured
(`POST /api/generate-tts`), or temporarily use the browser's SpeechSynthesis
fallback recording just to have *something* to demo before Monlam access is
approved (clearly not production audio quality).
