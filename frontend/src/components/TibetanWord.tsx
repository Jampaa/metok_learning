interface TibetanWordProps {
  text: string
  size?: 'md' | 'lg' | 'xl'
  faded?: boolean
  verified?: boolean
}

const sizeClasses = {
  md: 'text-3xl',
  lg: 'text-4xl',
  xl: 'text-6xl',
}

/**
 * Renders Tibetan Uchen text with the correct font stack.
 *
 * Two distinct "not fully trusted" states, shown differently:
 *  - No real text at all (offline-demo placeholder `TODO_VERIFY`, or empty)
 *    -> hide it, show "translation pending review" — there's nothing to show.
 *  - Real text exists but isn't dictionary-verified (Monlam's LLM fallback,
 *    used when the dictionary itself was unavailable — see
 *    backend/app/services/monlam_chat.py's translate_word) -> SHOW the word
 *    (hiding a real answer just to be cautious defeats the point of having
 *    a fallback), with a small "not dictionary-verified" marker underneath.
 */
export function TibetanWord({ text, size = 'lg', faded = false, verified = true }: TibetanWordProps) {
  const hasRealText = Boolean(text) && text !== 'TODO_VERIFY'

  if (!hasRealText) {
    return <span className="tibetan text-lg text-ink/40 italic">translation pending review</span>
  }

  return (
    <span className="inline-flex flex-col items-center">
      <span className={`tibetan font-bold ${sizeClasses[size]} ${faded ? 'text-ink/20' : 'text-ink'}`}>{text}</span>
      {!verified && !faded && <span className="mt-1 text-xs italic text-ink/40">not dictionary-verified yet</span>}
    </span>
  )
}
