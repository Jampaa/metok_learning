import { useEffect, useState } from 'react'

interface StarRewardProps {
  amount: number
  trigger: number
}

/** Pops up "+N ⭐" and fades out. Bump `trigger` (e.g. Date-free counter) to replay it. */
export function StarReward({ amount, trigger }: StarRewardProps) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    if (trigger === 0) return
    setVisible(true)
    const timeout = setTimeout(() => setVisible(false), 1400)
    return () => clearTimeout(timeout)
  }, [trigger])

  if (!visible) return null

  return (
    <div className="pointer-events-none fixed inset-x-0 top-24 z-50 flex justify-center">
      <div className="animate-bounce rounded-full bg-adventure px-6 py-3 text-2xl font-extrabold text-ink shadow-lg">
        +{amount} ⭐
      </div>
    </div>
  )
}
