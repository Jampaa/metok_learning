import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { getVocabularyById } from '../../data/vocabulary'
import { WordCard } from '../../components/WordCard'
import { Button } from '../../components/Button'
import { StarReward } from '../../components/StarReward'
import { useProgress } from '../../hooks/useProgress'

export function WordDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { progress, logEvent, addStars } = useProgress()
  const [rewardTick, setRewardTick] = useState(0)
  const item = id ? (progress.discoveredWords[id] ?? getVocabularyById(id)) : undefined

  useEffect(() => {
    if (item) logEvent(item.id, 'word_viewed')
  }, [item?.id])

  if (!item) {
    return (
      <div className="flex flex-col items-center gap-4 px-5 pt-16 text-center">
        <p className="text-lg font-bold">We couldn't find that word.</p>
        <Button onClick={() => navigate('/home')}>Back to Scanner</Button>
      </div>
    )
  }

  const awardFirstListen = () => {
    logEvent(item.id, 'audio_played')
    setRewardTick((t) => t + 1)
    addStars(10)
  }

  return (
    <div className="flex flex-col gap-5 px-5 pb-28 pt-8">
      <StarReward amount={10} trigger={rewardTick} />
      <WordCard item={item} onListen={awardFirstListen} />

      <div className="grid grid-cols-2 gap-3">
        <Button variant="sky" onClick={() => navigate(`/learn/word/${item.id}/trace`)}>
          ✍️ Trace
        </Button>
        <Button
          variant="ghost"
          disabled={item.sentences.length === 0}
          onClick={() => navigate(`/learn/word/${item.id}/practice`)}
        >
          💬 Practice
        </Button>
      </div>

      <Button variant="adventure" onClick={() => navigate('/home')}>
        📷 Scan Something Else
      </Button>
    </div>
  )
}
