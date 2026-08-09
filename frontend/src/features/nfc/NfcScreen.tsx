import { useEffect, useState } from 'react'
import { vocabulary } from '../../data/vocabulary'
import { getVocabularyById } from '../../data/vocabulary'
import { WordCard } from '../../components/WordCard'
import { Button } from '../../components/Button'
import { useProgress } from '../../hooks/useProgress'

/**
 * Real NFC only works via the Web NFC API, which is Android Chrome only and
 * requires HTTPS — it will never work for the ESP32 physical-toy demo (that
 * path is UID -> local lookup -> speaker, entirely on the device, see
 * hardware/esp32-nfc-toy). This screen exists so the *web app* can still
 * demo an NFC-triggered word even without the physical toy in hand:
 * "Simulate Tap" always works and should be the fallback if hardware fails
 * on stage.
 */
export function NfcScreen() {
  const { logEvent, addStars } = useProgress()
  const [scannedId, setScannedId] = useState<string | null>(null)
  const [webNfcSupported, setWebNfcSupported] = useState(false)
  const [scanning, setScanning] = useState(false)

  useEffect(() => {
    setWebNfcSupported('NDEFReader' in window)
  }, [])

  const handleTap = (vocabId: string, source: 'nfc' | 'simulated') => {
    setScannedId(vocabId)
    logEvent(vocabId, 'nfc_detected', { source })
    logEvent(vocabId, 'nfc_audio_played', { source })
    addStars(5)
  }

  const startRealScan = async () => {
    setScanning(true)
    try {
      // @ts-expect-error Web NFC types aren't in default TS lib
      const reader = new window.NDEFReader()
      await reader.scan()
      reader.onreading = (event: { message: { records: { recordType: string; data: unknown }[] } }) => {
        const textRecord = event.message.records.find((r) => r.recordType === 'text')
        const decoded = textRecord ? new TextDecoder().decode(textRecord.data as BufferSource) : null
        if (decoded && getVocabularyById(decoded)) handleTap(decoded, 'nfc')
      }
    } catch {
      setScanning(false)
    }
  }

  const item = scannedId ? getVocabularyById(scannedId) : null
  const stickers = vocabulary.filter((v) => v.verified)

  return (
    <div className="flex flex-col gap-5 px-5 pb-28 pt-8">
      <div>
        <h1 className="text-2xl font-extrabold text-primary-dark">NFC Stickers 📡</h1>
        <p className="text-ink/60">Tap a real sticker with the ESP32 toy, or try it here on the web.</p>
      </div>

      {item ? (
        <WordCard item={item} onListen={() => logEvent(item.id, 'nfc_audio_played', { source: 'replay' })} />
      ) : (
        <div className="rounded-3xl bg-white p-6 text-center text-ink/50 shadow-[0_4px_0_rgba(0,0,0,0.06)]">
          No sticker scanned yet.
        </div>
      )}

      {webNfcSupported && (
        <Button variant="sky" onClick={startRealScan} disabled={scanning}>
          {scanning ? 'Scanning… hold sticker near phone' : '📱 Scan Real NFC Sticker'}
        </Button>
      )}
      {!webNfcSupported && (
        <p className="text-center text-xs text-ink/40">
          Real NFC scanning needs Android Chrome. Use the toy or simulate a tap below.
        </p>
      )}

      <div>
        <p className="mb-2 font-bold text-ink/70">Simulate a tap:</p>
        <div className="grid grid-cols-4 gap-2">
          {stickers.map((s) => (
            <button
              key={s.id}
              onClick={() => handleTap(s.id, 'simulated')}
              className="flex flex-col items-center gap-1 rounded-2xl border-2 border-cream-dark bg-white p-3 active:scale-95"
            >
              <span className="text-3xl">{s.emoji}</span>
              <span className="text-[10px] font-bold">{s.english}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
