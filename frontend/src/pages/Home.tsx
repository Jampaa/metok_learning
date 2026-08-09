import { useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { LoadingAnimation } from '../components/LoadingAnimation'
import { discoverObject } from '../services/api'
import { useProgress } from '../hooks/useProgress'
import type { VocabularyItem } from '../types'

type Status = 'idle' | 'looking' | 'low_confidence' | 'not_in_dictionary' | 'error'

/**
 * Camera-first home screen — scanning IS the primary action, bottom nav
 * stays for Games/NFC/Profile. Replaces the old 3-button Home + separate
 * Explorer grid: there's no static object list to browse anymore since
 * vocabulary is discovered dynamically (see docs/architecture.md).
 */
export function Home() {
  const navigate = useNavigate()
  const { progress, logEvent, addStars, rememberWord } = useProgress()
  const fileInput = useRef<HTMLInputElement>(null)
  const [status, setStatus] = useState<Status>('idle')
  const [lastObject, setLastObject] = useState('')
  const [errorMessage, setErrorMessage] = useState('')

  const handleCapture = async (file: File) => {
    setStatus('looking')
    setLastObject('')
    try {
      const result = await discoverObject(file)
      if (result.status === 'low_confidence') {
        setLastObject(result.object)
        setStatus('low_confidence')
        return
      }
      if (result.status === 'not_in_dictionary') {
        setLastObject(result.object)
        setStatus('not_in_dictionary')
        return
      }
      const item: VocabularyItem = result
      rememberWord(item)
      const isNewWord = !(item.id in progress.wordStats)
      logEvent(item.id, 'object_identified', { source: 'camera' })
      if (isNewWord) addStars(10)
      setStatus('idle')
      navigate(`/learn/word/${item.id}`)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : '')
      setStatus('error')
    }
  }

  if (status === 'looking') {
    return <LoadingAnimation />
  }

  return (
    <div className="flex min-h-full flex-col gap-4 px-5 pb-28 pt-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-extrabold text-primary-dark">Tashi's Adventure</h1>
          <p className="text-sm text-ink/60">Point, snap, and discover a word!</p>
        </div>
        <div className="rounded-full bg-adventure/20 px-3 py-1.5 text-sm font-extrabold text-adventure-dark">
          ⭐ {progress.stars}
        </div>
      </div>

      <input
        ref={fileInput}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0]
          if (file) void handleCapture(file)
          e.target.value = ''
        }}
      />

      <button
        onClick={() => fileInput.current?.click()}
        className="flex flex-1 flex-col items-center justify-center gap-4 rounded-[2rem] border-4 border-dashed border-primary bg-white active:bg-primary/5"
        style={{ minHeight: '55vh' }}
      >
        <span className="text-7xl">📷</span>
        <span className="text-lg font-extrabold text-primary">Tap to Scan Something</span>
        <span className="max-w-[220px] text-center text-sm text-ink/50">
          Try a pen, a mug, a chair — anything around you!
        </span>
      </button>

      {status === 'low_confidence' && (
        <div className="rounded-2xl bg-adventure/15 p-4 text-center text-adventure-dark">
          Not sure what that is — try getting closer or a brighter photo!
        </div>
      )}
      {status === 'not_in_dictionary' && (
        <div className="rounded-2xl bg-incorrect/10 p-4 text-center text-incorrect">
          We saw "{lastObject}" but don't have that word yet. Try something else!
        </div>
      )}
      {status === 'error' && (
        <div className="rounded-2xl bg-incorrect/10 p-4 text-center text-incorrect">
          {errorMessage === 'Please sign in to keep discovering words.' ? (
            <>
              Please sign in to keep discovering words. <Link to="/" className="underline">Go to sign in</Link>
            </>
          ) : (
            'Something went wrong — try another picture!'
          )}
        </div>
      )}
    </div>
  )
}
