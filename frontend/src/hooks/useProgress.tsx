import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { doc, getDoc, setDoc } from 'firebase/firestore'
import type { LearningEventType, UserProgress, VocabularyItem } from '../types'
import { sendLearningEvent } from '../services/api'
import { db } from '../firebase/client'
import { useAuthUser } from './useAuthUser'

const STORAGE_PREFIX = 'twa_progress_v2_'

const emptyStats = () => ({ heard: 0, traced: 0, found: 0, nfc: 0, quiz: 0 })

const defaultProgress: UserProgress = {
  stars: 0,
  level: 1,
  badges: [],
  unlockedAreas: ['school'],
  wordStats: {},
  discoveredWords: {},
}

/**
 * Progress is exclusive per signed-in account, not per browser — the key
 * used to be a single fixed string, which meant every visitor to a given
 * browser shared the same stars/discoveries. Now keyed by uid (or "guest"
 * when Firebase isn't configured), and mirrored to Firestore `progress/{uid}`
 * so a different device with the same account sees the same progress, and
 * a different account never sees someone else's.
 */
function localKey(uid: string | null): string {
  return `${STORAGE_PREFIX}${uid ?? 'guest'}`
}

function loadLocal(uid: string | null): UserProgress {
  try {
    const raw = localStorage.getItem(localKey(uid))
    if (!raw) return defaultProgress
    return { ...defaultProgress, ...JSON.parse(raw) }
  } catch {
    return defaultProgress
  }
}

interface ProgressContextValue {
  progress: UserProgress
  addStars: (amount: number) => void
  unlockBadge: (badge: string) => void
  logEvent: (vocabularyId: string, eventType: LearningEventType, meta?: Record<string, unknown>) => void
  rememberWord: (item: VocabularyItem) => void
}

const ProgressContext = createContext<ProgressContextValue | null>(null)

const statKeyForEvent: Partial<Record<LearningEventType, keyof ReturnType<typeof emptyStats>>> = {
  audio_played: 'heard',
  trace_completed: 'traced',
  object_identified: 'found',
  nfc_detected: 'nfc',
  nfc_audio_played: 'nfc',
  sentence_answered: 'quiz',
}

export function ProgressProvider({ children }: { children: ReactNode }) {
  const user = useAuthUser()
  const uid = user?.uid ?? null
  const [progress, setProgress] = useState<UserProgress>(() => loadLocal(uid))
  const hydratedUidRef = useRef<string | null>(null)

  // Whenever the signed-in account changes, drop any in-memory state from
  // the previous account immediately (no flash of someone else's data),
  // then load this account's own data — Firestore if available, else
  // whatever's cached locally for this specific uid.
  useEffect(() => {
    if (hydratedUidRef.current === uid) return
    hydratedUidRef.current = uid
    setProgress(loadLocal(uid))

    if (!db || !uid) return
    getDoc(doc(db, 'progress', uid))
      .then((snap) => {
        if (snap.exists()) {
          setProgress({ ...defaultProgress, ...(snap.data() as UserProgress) })
        }
      })
      .catch((err) => console.warn('Could not load cloud progress, using local cache:', err))
  }, [uid])

  useEffect(() => {
    localStorage.setItem(localKey(uid), JSON.stringify(progress))
    if (db && uid) {
      setDoc(doc(db, 'progress', uid), progress).catch((err) => console.warn('Could not sync progress to cloud:', err))
    }
  }, [progress, uid])

  const addStars = (amount: number) => {
    setProgress((prev) => {
      const stars = prev.stars + amount
      const unlockedAreas = [...prev.unlockedAreas]
      if (stars >= 50 && !unlockedAreas.includes('garden')) unlockedAreas.push('garden')
      if (stars >= 100 && !unlockedAreas.includes('market')) unlockedAreas.push('market')
      return { ...prev, stars, unlockedAreas }
    })
  }

  const unlockBadge = (badge: string) => {
    setProgress((prev) => (prev.badges.includes(badge) ? prev : { ...prev, badges: [...prev.badges, badge] }))
  }

  const logEvent = (vocabularyId: string, eventType: LearningEventType, meta?: Record<string, unknown>) => {
    const statKey = statKeyForEvent[eventType]
    if (statKey) {
      setProgress((prev) => {
        const current = prev.wordStats[vocabularyId] ?? emptyStats()
        return {
          ...prev,
          wordStats: {
            ...prev.wordStats,
            [vocabularyId]: { ...current, [statKey]: current[statKey] + 1 },
          },
        }
      })
    }
    void sendLearningEvent({ userId: uid, vocabularyId, eventType, source: 'web', timestamp: Date.now(), meta })
  }

  const rememberWord = (item: VocabularyItem) => {
    setProgress((prev) => ({ ...prev, discoveredWords: { ...prev.discoveredWords, [item.id]: item } }))
  }

  const value = useMemo(() => ({ progress, addStars, unlockBadge, logEvent, rememberWord }), [progress])

  return <ProgressContext.Provider value={value}>{children}</ProgressContext.Provider>
}

export function useProgress() {
  const ctx = useContext(ProgressContext)
  if (!ctx) throw new Error('useProgress must be used within ProgressProvider')
  return ctx
}
