import { useNavigate } from 'react-router-dom'
import { ObjectCard } from '../../components/ObjectCard'
import { useProgress } from '../../hooks/useProgress'

/**
 * "Learn" tab — a revisit list of words already discovered via the Home
 * scanner. There's no browsable catalog anymore since vocabulary is
 * discovered dynamically rather than pre-curated (see docs/architecture.md);
 * this screen reads from the locally-cached discoveredWords instead of a
 * static list.
 */
export function ExplorerScreen() {
  const navigate = useNavigate()
  const { progress } = useProgress()
  const words = Object.values(progress.discoveredWords)

  return (
    <div className="flex flex-col gap-6 px-5 pb-28 pt-8">
      <div>
        <h1 className="text-2xl font-extrabold text-primary-dark">Words I've Found</h1>
        <p className="text-ink/60">Tap a word to hear it again, trace it, or practice a sentence.</p>
      </div>

      {words.length === 0 ? (
        <div className="rounded-3xl bg-white p-6 text-center text-ink/50 shadow-[0_4px_0_rgba(0,0,0,0.06)]">
          Nothing yet — go scan something on the Home screen! 📷
        </div>
      ) : (
        <div className="grid grid-cols-3 gap-3">
          {words.map((item) => (
            <ObjectCard key={item.id} item={item} onClick={() => navigate(`/learn/word/${item.id}`)} />
          ))}
        </div>
      )}
    </div>
  )
}
