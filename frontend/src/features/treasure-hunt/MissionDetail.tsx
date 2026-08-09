import { useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { missions } from '../../data/missions'
import { ObjectCard } from '../../components/ObjectCard'
import { TreasureChest } from '../../components/TreasureChest'
import { Button } from '../../components/Button'
import { LoadingAnimation } from '../../components/LoadingAnimation'
import { StarReward } from '../../components/StarReward'
import { useProgress } from '../../hooks/useProgress'
import { discoverObject } from '../../services/api'

/**
 * Missions target a category + count (not specific pre-known words) — any
 * recognized item whose category matches counts, so "find 3 stationery
 * items" is satisfied by any 3 distinct stationery items the child scans,
 * covering "similar items should count" without needing an exact word list.
 */
export function MissionDetail() {
  const { missionId } = useParams<{ missionId: string }>()
  const navigate = useNavigate()
  const { progress, logEvent, addStars, unlockBadge, rememberWord } = useProgress()
  const mission = missions.find((m) => m.id === missionId)
  const fileInput = useRef<HTMLInputElement>(null)
  const [looking, setLooking] = useState(false)
  const [message, setMessage] = useState<string | null>(null)
  const [rewardTick, setRewardTick] = useState(0)
  const [completedTick, setCompletedTick] = useState(0)

  if (!mission) {
    return (
      <div className="px-5 pt-16 text-center">
        <p className="font-bold">Mission not found.</p>
        <Button className="mt-4" onClick={() => navigate('/games')}>
          Back
        </Button>
      </div>
    )
  }

  const foundItems = Object.values(progress.discoveredWords).filter(
    (item) => item.category === mission.targetCategory && (progress.wordStats[item.id]?.found ?? 0) > 0,
  )
  const allFound = foundItems.length >= mission.requiredCount

  const markFound = (vocabId: string) => {
    logEvent(vocabId, 'object_identified', { source: 'mission', missionId: mission.id })
    addStars(10)
    setRewardTick((t) => t + 1)
    const willComplete = foundItems.length + 1 >= mission.requiredCount
    if (willComplete) {
      logEvent(vocabId, 'mission_completed', { missionId: mission.id })
      addStars(mission.reward)
      unlockBadge(mission.badge)
      setCompletedTick((t) => t + 1)
    }
  }

  const handleCapture = async (file: File) => {
    setLooking(true)
    setMessage(null)
    try {
      const result = await discoverObject(file)
      if (result.status === 'low_confidence') {
        setMessage("Not sure what that is — try getting closer!")
        return
      }
      if (result.status === 'not_in_dictionary') {
        setMessage("We don't have that word yet — try something else!")
        return
      }
      rememberWord(result)
      if (result.category !== mission.targetCategory) {
        setMessage(`That's a ${result.category} item, not ${mission.targetCategory} — keep looking!`)
        return
      }
      if (foundItems.some((item) => item.id === result.id)) {
        setMessage(`You already found ${result.english}! Try a different one.`)
        return
      }
      markFound(result.id)
      setMessage(`Found! ${result.english}`)
    } catch {
      setMessage("We couldn't identify that. Try again!")
    } finally {
      setLooking(false)
    }
  }

  return (
    <div className="flex flex-col gap-5 px-5 pb-28 pt-8">
      <StarReward amount={10} trigger={rewardTick} />
      <div>
        <h1 className="text-xl font-extrabold text-primary-dark">🏴‍☠️ {mission.title}</h1>
        <p className="text-ink/60">{mission.description}</p>
        <p className="mt-1 text-sm font-bold text-adventure-dark">
          {foundItems.length}/{mission.requiredCount} found
        </p>
      </div>

      <div className="flex justify-center">
        <TreasureChest open={allFound} />
      </div>

      {allFound && completedTick > 0 && (
        <div className="rounded-2xl bg-adventure/20 p-4 text-center font-bold text-adventure-dark">
          +{mission.reward} ⭐ New badge unlocked: {mission.badge}!
        </div>
      )}

      {looking ? (
        <LoadingAnimation />
      ) : (
        <>
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
          {!allFound && (
            <button
              onClick={() => fileInput.current?.click()}
              className="rounded-3xl border-2 border-dashed border-primary bg-white py-5 text-center font-bold text-primary active:bg-primary/5"
            >
              📷 Take a Picture
            </button>
          )}
          {message && <p className="text-center font-bold text-ink/70">{message}</p>}
        </>
      )}

      {foundItems.length > 0 && (
        <div className="grid grid-cols-3 gap-3">
          {foundItems.map((item) => (
            <ObjectCard key={item.id} item={item} found onClick={() => navigate(`/learn/word/${item.id}`)} />
          ))}
        </div>
      )}

      <Button variant="ghost" onClick={() => navigate('/games')}>
        Back to Missions
      </Button>
    </div>
  )
}
