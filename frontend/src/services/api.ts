/**
 * Thin client for the FastAPI backend. Falls back to local mocks when
 * VITE_API_URL isn't set, so the app is fully demoable before the backend
 * (and its Gemini/Monlam keys) is wired up. See backend/README section of
 * the root README for setup.
 */
import { vocabulary } from '../data/vocabulary'
import { auth } from '../firebase/client'
import type { DiscoverResult } from '../types'

const API_URL = import.meta.env.VITE_API_URL as string | undefined

const MOCK_LATENCY = 900

const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

/** Offline-demo stand-in for POST /api/discover — picks randomly from the local pool. */
async function mockDiscover(): Promise<DiscoverResult> {
  await delay(MOCK_LATENCY)
  const pool = vocabulary.filter((v) => v.verified)
  const pick = pool[Math.floor(Math.random() * pool.length)]
  return { status: 'ok', ...pick }
}

/**
 * One call: photo -> Gemini recognition -> Monlam dictionary/TTS/sentences
 * (cached after the first time) -> a full word result, or a
 * low_confidence/not_in_dictionary status. See backend/app/routes/discovery.py.
 */
export async function discoverObject(image: Blob): Promise<DiscoverResult> {
  if (!API_URL) {
    return mockDiscover()
  }
  const form = new FormData()
  form.append('image', image, 'capture.jpg')

  // Required once Firebase is configured — the backend uses this to keep
  // each account's own photos/discoveries exclusive (see routes/discovery.py).
  // Falls through with no header when signed out; the backend then 401s
  // with a clear "please sign in" message rather than silently misbehaving.
  const headers: Record<string, string> = {}
  const token = await auth?.currentUser?.getIdToken()
  if (token) headers.Authorization = `Bearer ${token}`

  const res = await fetch(`${API_URL}/api/discover`, {
    method: 'POST',
    headers,
    body: form,
  })
  if (res.status === 401) {
    throw new Error('Please sign in to keep discovering words.')
  }
  if (!res.ok) {
    throw new Error(`Discovery failed: ${res.status}`)
  }
  return res.json()
}

export async function requestTtsAudioUrl(text: string): Promise<string | null> {
  if (!API_URL) {
    // No backend configured — rely on the browser's own speech synthesis fallback (see useAudio hook).
    return null
  }
  const res = await fetch(`${API_URL}/api/generate-tts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  })
  if (!res.ok) return null
  const data = await res.json()
  return data.audioUrl ?? null
}

export async function sendLearningEvent(event: Record<string, unknown>): Promise<void> {
  if (!API_URL) {
    console.debug('[learning-event:local]', event)
    return
  }
  try {
    await fetch(`${API_URL}/api/learning-event`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(event),
    })
  } catch {
    // Never let analytics failures break the child's experience.
  }
}

export const isBackendConfigured = Boolean(API_URL)
