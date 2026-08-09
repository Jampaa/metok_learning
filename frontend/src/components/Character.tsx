interface CharacterProps {
  mood?: 'happy' | 'thinking' | 'excited'
  size?: 'md' | 'lg'
}

const moodEmoji: Record<Required<CharacterProps>['mood'], string> = {
  happy: '🐂',
  thinking: '🐂',
  excited: '🐂',
}

/**
 * Placeholder for the yak guide character (see assets/characters/).
 * Swap the emoji for the real illustration without touching call sites.
 */
export function Character({ mood = 'happy', size = 'md' }: CharacterProps) {
  return <span className={size === 'lg' ? 'text-8xl' : 'text-5xl'}>{moodEmoji[mood]}</span>
}
