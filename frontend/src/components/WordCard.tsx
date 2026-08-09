import type { VocabularyItem } from '../types'
import { TibetanWord } from './TibetanWord'
import { AudioButton } from './AudioButton'
import { ObjectThumbnail } from './ObjectThumbnail'

interface WordCardProps {
  item: VocabularyItem
  onListen?: () => void
  children?: React.ReactNode
}

/** The core "discovery" card: photo/emoji + English object + Tibetan word + audio. Reused by Explorer, Treasure Hunt, and NFC screens. */
export function WordCard({ item, onListen, children }: WordCardProps) {
  return (
    <div className="rounded-[2rem] bg-white p-6 text-center shadow-[0_6px_0_rgba(0,0,0,0.08)]">
      <div className="flex justify-center">
        <ObjectThumbnail imageUrl={item.imageUrl} emoji={item.emoji} alt={item.english} size="lg" />
      </div>
      <p className="mt-1 text-lg font-bold capitalize text-ink/60">{item.english}</p>
      <div className="mt-3">
        <TibetanWord text={item.tibetan} verified={item.verified} size="xl" />
      </div>
      <div className="mt-5 flex justify-center">
        <AudioButton tibetanText={item.tibetan} audioUrl={item.audioUrl} onPlay={onListen} />
      </div>
      {children}
    </div>
  )
}
