import { useEffect, useState } from 'react'
import { onAuthStateChanged, type User } from 'firebase/auth'
import { auth } from '../firebase/client'

/** Reactively tracks the current Firebase user (null if signed out, offline demo mode, or not yet resolved). */
export function useAuthUser() {
  const [user, setUser] = useState<User | null>(auth?.currentUser ?? null)

  useEffect(() => {
    if (!auth) return
    return onAuthStateChanged(auth, setUser)
  }, [])

  return user
}
