/*
  Tibetan Word Adventure — ESP32 NFC Toy (reference sketch)

  UNTESTED ON REAL HARDWARE — this repo was built without physical parts on
  hand. It's a correct-shaped starting point (PN532 UID read -> local
  lookup -> SPIFFS MP3 playback), but expect to tune SPI pins, I2S pins, and
  library versions once you have the actual board in hand. See
  docs/hardware.md for the demo-safety rationale (always keep the web
  "Simulate Tap" fallback ready).

  Required Arduino libraries (Library Manager):
    - Adafruit_PN532
    - ESP8266Audio (works on ESP32 too — AudioFileSourceSPIFFS,
      AudioGeneratorMP3, AudioOutputI2S)

  Wiring (adjust to your board — see hardware/wiring/):
    PN532 (SPI): SCK, MOSI, MISO, SS -> ESP32 default VSPI pins
    MAX98357A:   BCLK, LRC, DIN      -> I2S pins defined below

  Setup once per sticker set:
    1. Flash this sketch, open Serial Monitor at 115200 baud.
    2. Tap each sticker; note the UID it prints.
    3. Fill in TAG_MAP below with those UIDs -> word ids.
    4. Upload matching mp3 files (e.g. pen.mp3) to SPIFFS via the
       "ESP32 Sketch Data Upload" tool, named exactly as in TAG_MAP.
*/

#include <SPI.h>
#include <Adafruit_PN532.h>
#include <SPIFFS.h>
#include <AudioFileSourceSPIFFS.h>
#include <AudioGeneratorMP3.h>
#include <AudioOutputI2S.h>

#define PN532_SS 5
Adafruit_PN532 nfc(PN532_SS);

#define I2S_BCLK 26
#define I2S_LRC 25
#define I2S_DOUT 22

AudioGeneratorMP3 *mp3;
AudioFileSourceSPIFFS *file;
AudioOutputI2S *out;

struct TagMapping {
  const char *uidHex;   // e.g. "04A821B3"
  const char *wordId;   // matches vocabulary/{id} in Firestore
  const char *mp3Path;  // e.g. "/pen.mp3"
};

// Fill in with real UIDs once stickers are tapped (see docs/hardware.md).
TagMapping TAG_MAP[] = {
  {"TODO_UID_1", "pen", "/pen.mp3"},
  {"TODO_UID_2", "pencil", "/pencil.mp3"},
  {"TODO_UID_3", "notebook", "/notebook.mp3"},
};
const int TAG_MAP_SIZE = sizeof(TAG_MAP) / sizeof(TAG_MAP[0]);

String uidToHex(uint8_t *uid, uint8_t length) {
  String hex = "";
  for (uint8_t i = 0; i < length; i++) {
    if (uid[i] < 0x10) hex += "0";
    hex += String(uid[i], HEX);
  }
  hex.toUpperCase();
  return hex;
}

const char *lookupMp3(const String &uidHex) {
  for (int i = 0; i < TAG_MAP_SIZE; i++) {
    if (uidHex.equalsIgnoreCase(TAG_MAP[i].uidHex)) {
      return TAG_MAP[i].mp3Path;
    }
  }
  return nullptr;
}

void playMp3(const char *path) {
  if (!SPIFFS.exists(path)) {
    Serial.printf("Missing audio file: %s\n", path);
    return;
  }
  file = new AudioFileSourceSPIFFS(path);
  mp3 = new AudioGeneratorMP3();
  mp3->begin(file, out);
  while (mp3->isRunning()) {
    if (!mp3->loop()) mp3->stop();
  }
  delete mp3;
  delete file;
}

void setup() {
  Serial.begin(115200);
  Serial.println("Tibetan Word Adventure — NFC toy starting...");

  if (!SPIFFS.begin(true)) {
    Serial.println("SPIFFS mount failed");
  }

  nfc.begin();
  if (!nfc.getFirmwareVersion()) {
    Serial.println("PN532 not found — check wiring");
    while (true) delay(1000);
  }
  nfc.SAMConfig();

  out = new AudioOutputI2S();
  out->SetPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);

  Serial.println("Ready. Tap a sticker.");
}

void loop() {
  uint8_t uid[7];
  uint8_t uidLength;

  if (nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 500)) {
    String uidHex = uidToHex(uid, uidLength);
    Serial.printf("Tag detected: %s\n", uidHex.c_str());

    const char *path = lookupMp3(uidHex);
    if (path) {
      playMp3(path);
      // Optional: if Wi-Fi is connected, POST { tagUid: uidHex } to
      // /api/nfc-event here. Never block playback on this — the speaker
      // must respond instantly regardless of network state.
    } else {
      Serial.println("Unknown tag — add it to TAG_MAP");
    }

    delay(1500); // debounce so one tap doesn't replay several times
  }
}
