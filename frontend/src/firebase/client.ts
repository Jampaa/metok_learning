import { initializeApp, type FirebaseApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider, signInAnonymously, signInWithPopup, signOut, type Auth } from 'firebase/auth'
import { getFirestore, type Firestore } from 'firebase/firestore'

const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

export const isFirebaseConfigured = Boolean(config.apiKey && config.projectId)

let app: FirebaseApp | undefined
let auth: Auth | undefined
let db: Firestore | undefined

if (isFirebaseConfigured) {
  app = initializeApp(config)
  auth = getAuth(app)
  db = getFirestore(app)
}

export { app, auth, db }

/** Signs the child in anonymously. No-ops (returns null) when Firebase isn't configured yet. */
export async function ensureAnonymousSignIn() {
  if (!auth) return null
  const credential = await signInAnonymously(auth)
  return credential.user
}

/**
 * Google sign-in — for a parent/returning user who wants progress synced
 * across devices, rather than the default anonymous per-device flow
 * (Section 24: kids shouldn't need a signup screen, so this stays optional).
 */
export async function signInWithGoogle() {
  if (!auth) return null
  const credential = await signInWithPopup(auth, new GoogleAuthProvider())
  return credential.user
}

/** Signs out entirely. No-ops when Firebase isn't configured. */
export async function signOutUser() {
  if (!auth) return
  await signOut(auth)
}
