import { motion } from 'framer-motion'

interface TreasureChestProps {
  open: boolean
}

/** Placeholder illustrated treasure chest. Swap for assets/ui/treasure-chest.svg when the real art lands. */
export function TreasureChest({ open }: TreasureChestProps) {
  return (
    <motion.div
      initial={false}
      animate={open ? { scale: [1, 1.15, 1] } : {}}
      transition={{ duration: 0.6 }}
      className="flex flex-col items-center"
    >
      <span className="text-8xl">{open ? '📦✨' : '📦'}</span>
      <p className="mt-2 text-lg font-extrabold text-treasure">{open ? 'TREASURE FOUND!' : 'Keep exploring...'}</p>
    </motion.div>
  )
}
