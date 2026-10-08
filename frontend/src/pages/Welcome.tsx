import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Button } from '../components/Button'
import {
  ensureAnonymousSignIn,
  handleGoogleRedirectResult,
  isFirebaseConfigured,
  signInWithGoogle,
} from '../firebase/client'

export function Welcome() {
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const [checkingRedirect, setCheckingRedirect] = useState(isFirebaseConfigured)

  // Completes the signInWithGoogle() redirect flow — the page fully
  // navigated away to Google and back, so this runs once on load to pick
  // up the result rather than getting it as a return value from a click handler.
  useEffect(() => {
    if (!isFirebaseConfigured) return
    handleGoogleRedirectResult()
      .then((user) => {
        if (user) navigate('/home')
      })
      .catch((err) => {
        console.error('Google sign-in failed:', err)
        setError("Couldn't sign in with Google — try again, or just start below.")
      })
      .finally(() => setCheckingRedirect(false))
  }, [navigate])

  const start = async () => {
    if (isFirebaseConfigured) {
      try {
        await ensureAnonymousSignIn()
      } catch {
        // Fall through to local-only mode; the app still works offline.
      }
    }
    navigate('/home')
  }

  const startWithGoogle = async () => {
    setError(null)
    try {
      await signInWithGoogle() // navigates away to Google — nothing after this line runs
    } catch (err) {
      console.error('Google sign-in failed:', err)
      setError("Couldn't sign in with Google — try again, or just start below.")
    }
  }

  if (checkingRedirect) {
    // Briefly shown right after bouncing back from Google — avoids a flash
    // of the sign-in buttons before we know whether it actually succeeded.
    return (
      <div className="flex min-h-full flex-col items-center justify-center gap-4 px-6 text-center">
        <div className="text-6xl">🐂</div>
        <p className="text-ink/50">Signing you in...</p>
      </div>
    )
  }

  return (
    <div className="flex min-h-full flex-col items-center justify-center gap-6 px-6 text-center">
      <div className="text-8xl">🐂🗺️</div>
      <div>
        <h1 className="font-display text-3xl font-extrabold text-primary-dark">Tashi's Tibetan Adventure</h1>
        <p className="mt-2 text-lg text-ink/70">What will we discover today?</p>
      </div>

      <Button variant="adventure" className="w-full max-w-xs" onClick={start}>
        Start the Adventure 🚀
      </Button>

      {isFirebaseConfigured && (
        <>
          <p className="text-sm text-ink/40">or, for parents — save progress across devices</p>
          <Button variant="ghost" className="w-full max-w-xs" onClick={startWithGoogle}>
            <GoogleIcon />
            Sign in with Google
          </Button>
        </>
      )}

      {error && <p className="max-w-xs text-sm text-incorrect">{error}</p>}

      {!isFirebaseConfigured && (
        <p className="max-w-xs text-xs text-ink/40">
          Playing in offline demo mode — progress is saved on this device only.
        </p>
      )}
    </div>
  )
}

function GoogleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 48 48" aria-hidden>
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.4 29.3 35 24 35c-6.1 0-11-4.9-11-11s4.9-11 11-11c2.8 0 5.3 1 7.3 2.7l5.7-5.7C33.6 6.5 29.1 4.5 24 4.5 13.2 4.5 4.5 13.2 4.5 24S13.2 43.5 24 43.5 43.5 34.8 43.5 24c0-1.2-.1-2.4-.4-3.5z" />
      <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.5 16 18.9 13.5 24 13.5c2.8 0 5.3 1 7.3 2.7l5.7-5.7C33.6 6.5 29.1 4.5 24 4.5c-7.6 0-14.1 4.3-17.7 10.2z" />
      <path fill="#4CAF50" d="M24 43.5c5 0 9.5-1.9 12.9-5l-6-5c-2 1.3-4.4 2-6.9 2-5.3 0-9.7-2.6-11.3-7.4l-6.5 5C9.8 39.2 16.3 43.5 24 43.5z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.3 5.7l6 5C40.7 35.6 43.5 30.2 43.5 24c0-1.2-.1-2.4-.4-3.5z" />
    </svg>
  )
}
