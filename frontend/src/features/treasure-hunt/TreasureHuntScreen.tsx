import { useNavigate } from 'react-router-dom'
import { missions } from '../../data/missions'
import { MissionCard } from '../../components/MissionCard'
import { useProgress } from '../../hooks/useProgress'

export function TreasureHuntScreen() {
  const navigate = useNavigate()
  const { progress } = useProgress()

  return (
    <div className="flex flex-col gap-5 px-5 pb-28 pt-8">
      <div>
        <h1 className="text-2xl font-extrabold text-primary-dark">Treasure Hunt 🗺️</h1>
        <p className="text-ink/60">Pick a mission and go find the objects!</p>
      </div>

      {missions.map((mission) => {
        const foundCount = Object.values(progress.discoveredWords).filter(
          (item) => item.category === mission.targetCategory && (progress.wordStats[item.id]?.found ?? 0) > 0,
        ).length
        return (
          <MissionCard
            key={mission.id}
            mission={mission}
            foundCount={foundCount}
            onClick={() => navigate(`/games/${mission.id}`)}
          />
        )
      })}
    </div>
  )
}
