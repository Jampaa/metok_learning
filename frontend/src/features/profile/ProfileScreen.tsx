import { useNavigate } from 'react-router-dom'
import { ProgressBar } from '../../components/ProgressBar'
import { Character } from '../../components/Character'
import { Button } from '../../components/Button'
import { useProgress } from '../../hooks/useProgress'
import { useAuthUser } from '../../hooks/useAuthUser'
import { signOutUser } from '../../firebase/client'

export function ProfileScreen() {
  const navigate = useNavigate()
  const { progress } = useProgress()
  const user = useAuthUser()
  const touched = Object.values(progress.discoveredWords).filter((v) => progress.wordStats[v.id])

  const logOut = async () => {
    await signOutUser()
    navigate('/')
  }

  return (
    <div className="flex flex-col gap-6 px-5 pb-28 pt-8">
      <div className="flex items-center gap-3">
        <Character size="lg" />
        <div>
          <h1 className="text-2xl font-extrabold text-primary-dark">My Progress</h1>
          <p className="text-ink/60">⭐ {progress.stars} stars · Level {progress.level}</p>
        </div>
      </div>

      {user && (
        <div className="flex items-center justify-between rounded-2xl bg-white p-4 shadow-[0_2px_0_rgba(0,0,0,0.06)]">
          <div>
            <p className="text-sm font-bold text-ink/70">
              {user.isAnonymous ? 'Playing as Guest' : user.displayName || user.email}
            </p>
            {!user.isAnonymous && user.email && <p className="text-xs text-ink/40">{user.email}</p>}
          </div>
          <Button variant="ghost" className="px-4 py-2 text-sm" onClick={logOut}>
            Log Out
          </Button>
        </div>
      )}

      <div>
        <p className="mb-2 font-bold text-ink/70">Next area unlock</p>
        <ProgressBar value={progress.stars % 50} max={50} />
      </div>

      {progress.badges.length > 0 && (
        <div>
          <p className="mb-2 font-bold text-ink/70">Badges</p>
          <div className="flex flex-wrap gap-2">
            {progress.badges.map((b) => (
              <span key={b} className="rounded-full bg-adventure/20 px-3 py-1 text-sm font-bold text-adventure-dark">
                🏆 {b}
              </span>
            ))}
          </div>
        </div>
      )}

      <div>
        <p className="mb-2 font-bold text-ink/70">Words I'm learning</p>
        {touched.length === 0 && <p className="text-ink/40">Go explore to start tracking words!</p>}
        <div className="flex flex-col gap-2">
          {touched.map((item) => {
            const stats = progress.wordStats[item.id]
            return (
              <div key={item.id} className="rounded-2xl bg-white p-4 shadow-[0_2px_0_rgba(0,0,0,0.06)]">
                <p className="font-bold">
                  {item.emoji} {item.english}
                </p>
                <p className="mt-1 text-sm text-ink/60">
                  Heard: {stats.heard} · Traced: {stats.traced} · Found: {stats.found} · NFC: {stats.nfc} · Quiz: {stats.quiz}
                </p>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
