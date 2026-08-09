import type { VocabularyItem } from '../types'
import { ObjectThumbnail } from './ObjectThumbnail'

interface ObjectCardProps {
  item: VocabularyItem
  found?: boolean
  onClick?: () => void
}

/** A tappable photo/emoji object tile used in the Learn list and Treasure Hunt grids. */
export function ObjectCard({ item, found = false, onClick }: ObjectCardProps) {
  return (
    <button
      onClick={onClick}
      className={`flex flex-col items-center gap-1 rounded-3xl border-2 p-3 transition active:scale-95 ${
        found ? 'border-primary bg-primary/10' : 'border-cream-dark bg-white'
      }`}
    >
      <ObjectThumbnail imageUrl={item.imageUrl} emoji={item.emoji} alt={item.english} size="sm" />
      <span className="text-sm font-bold capitalize text-ink/80">{item.english}</span>
      {found && <span className="text-xs font-bold text-primary">Found ✓</span>}
    </button>
  )
}
