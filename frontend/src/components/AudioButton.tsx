import { useTibetanAudio } from '../hooks/useTibetanAudio'

interface AudioButtonProps {
  tibetanText: string
  audioUrl?: string
  onPlay?: () => void
  label?: string
}

export function AudioButton({ tibetanText, audioUrl, onPlay, label = 'Listen' }: AudioButtonProps) {
  const { play, state } = useTibetanAudio(tibetanText, audioUrl)

  return (
    <button
      onClick={() => {
        onPlay?.()
        void play()
      }}
      disabled={state === 'loading'}
      className="flex items-center gap-2 rounded-full bg-sky px-5 py-3 text-white font-bold shadow-[0_4px_0_rgba(0,0,0,0.15)] active:translate-y-0.5 active:shadow-[0_1px_0_rgba(0,0,0,0.15)] disabled:opacity-60"
    >
      <span className={`text-xl ${state === 'playing' ? 'animate-pulse' : ''}`}>🔊</span>
      {state === 'loading' ? 'Preparing…' : label}
    </button>
  )
}
