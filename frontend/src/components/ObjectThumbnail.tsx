interface ObjectThumbnailProps {
  imageUrl?: string
  emoji: string
  alt: string
  size?: 'sm' | 'lg'
}

const sizeClasses = {
  sm: 'h-20 w-20',
  lg: 'h-36 w-36',
}

const emojiSizeClasses = {
  sm: 'text-4xl',
  lg: 'text-7xl',
}

/**
 * Fixed-size, fixed-aspect-ratio box for a discovered object's photo —
 * `object-cover` crops any photo (portrait, landscape, square) to fill the
 * same box, so the grid/card layout never shifts based on how a child held
 * their phone. Falls back to the category emoji when there's no photo yet
 * (offline-demo words, or Storage not configured).
 */
export function ObjectThumbnail({ imageUrl, emoji, alt, size = 'lg' }: ObjectThumbnailProps) {
  return (
    <div className={`flex shrink-0 items-center justify-center overflow-hidden rounded-3xl bg-cream-dark ${sizeClasses[size]}`}>
      {imageUrl ? (
        <img src={imageUrl} alt={alt} className="h-full w-full object-cover" />
      ) : (
        <span className={emojiSizeClasses[size]} aria-hidden>
          {emoji}
        </span>
      )}
    </div>
  )
}
