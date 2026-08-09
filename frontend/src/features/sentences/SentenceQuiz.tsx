import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { getVocabularyById } from '../../data/vocabulary'
import { Button } from '../../components/Button'
import { AudioButton } from '../../components/AudioButton'
import { StarReward } from '../../components/StarReward'
import { useProgress } from '../../hooks/useProgress'

/**
 * Sentence Practice — shows Monlam-generated example sentences for the word.
 * These are simple examples (english + tibetan), not a fill-in-blank quiz:
 * dynamically generated sentences don't come with curated wrong-answer
 * options the way the old hand-authored spec example did, so this is a
 * read-and-listen activity rather than multiple choice.
 */
export function SentenceQuiz() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { progress, logEvent, addStars } = useProgress()
  const item = id ? (progress.discoveredWords[id] ?? getVocabularyById(id)) : undefined
  const [index, setIndex] = useState(0)
  const [rewardTick, setRewardTick] = useState(0)

  if (!item || item.sentences.length === 0) {
    return (
      <div className="px-5 pt-16 text-center">
        <p className="font-bold">No sentence practice for this word yet.</p>
        <Button className="mt-4" onClick={() => navigate('/learn')}>
          Back
        </Button>
      </div>
    )
  }

  const sentence = item.sentences[index]

  const markLearned = () => {
    logEvent(item.id, 'sentence_answered', { index })
    addStars(10)
    setRewardTick((t) => t + 1)
    if (index < item.sentences.length - 1) setIndex(index + 1)
  }

  return (
    <div className="flex flex-col gap-6 px-5 pb-28 pt-8">
      <StarReward amount={10} trigger={rewardTick} />
      <h1 className="text-xl font-extrabold text-primary-dark">Sentence Practice 💬</h1>
      <p className="text-sm text-ink/50">
        Sentence {index + 1} of {item.sentences.length}
      </p>

      <div className="rounded-3xl bg-white p-6 text-center shadow-[0_4px_0_rgba(0,0,0,0.06)]">
        <p className="tibetan text-3xl font-bold">{sentence.tibetan}</p>
        <p className="mt-3 text-ink/60">{sentence.english}</p>
        <div className="mt-4 flex justify-center">
          <AudioButton tibetanText={sentence.tibetan} audioUrl={sentence.audioUrl} />
        </div>
      </div>

      <Button variant="primary" onClick={markLearned}>
        {index < item.sentences.length - 1 ? 'Got it! Next sentence →' : 'Got it! 🎉'}
      </Button>

      <Button variant="adventure" onClick={() => navigate(`/learn/word/${item.id}`)}>
        Back to Word
      </Button>
    </div>
  )
}
