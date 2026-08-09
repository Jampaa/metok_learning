import type { Mission } from '../types'

interface MissionCardProps {
  mission: Mission
  foundCount: number
  onClick?: () => void
}

export function MissionCard({ mission, foundCount, onClick }: MissionCardProps) {
  const total = mission.requiredCount
  return (
    <button
      onClick={onClick}
      className="w-full rounded-3xl border-2 border-adventure bg-white p-5 text-left shadow-[0_4px_0_rgba(0,0,0,0.08)] active:scale-[0.98]"
    >
      <p className="text-xl font-extrabold">🏴‍☠️ {mission.title}</p>
      <p className="mt-1 text-ink/70">{mission.description}</p>
      <p className="mt-3 text-sm font-bold text-adventure-dark">
        {foundCount}/{total} found · +{mission.reward} ⭐
      </p>
    </button>
  )
}
