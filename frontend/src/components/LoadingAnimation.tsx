import { useEffect, useState } from 'react'

const messages = ['🔍 Looking closely...', '🐂 Hmm... what did we find?', '📚 Finding the Tibetan word...']

/** Friendly rotating loading copy per spec Section 33 — never show a bare spinner or "Loading...". */
export function LoadingAnimation() {
  const [index, setIndex] = useState(0)

  useEffect(() => {
    const interval = setInterval(() => setIndex((i) => (i + 1) % messages.length), 900)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="flex flex-col items-center gap-3 py-10 text-center">
      <span className="animate-bounce text-5xl">🐂</span>
      <p className="text-lg font-bold text-ink/70">{messages[index]}</p>
    </div>
  )
}
