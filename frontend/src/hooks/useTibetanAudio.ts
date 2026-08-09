import { useCallback, useRef, useState } from 'react'
import { requestTtsAudioUrl } from '../services/api'

type PlayState = 'idle' | 'loading' | 'playing' | 'error'

/**
 * Plays pre-generated Monlam audio when available. If no audioUrl exists
 * and no backend is configured, falls back to the browser's SpeechSynthesis
 * (best-effort only — most browsers lack a Tibetan voice, so this mostly
 * exists so the Listen button never feels broken during offline demos).
 */
export function useTibetanAudio(tibetanText: string, audioUrl?: string) {
  const [state, setState] = useState<PlayState>('idle')
  const audioRef = useRef<HTMLAudioElement | null>(null)

  const play = useCallback(async () => {
    setState('loading')
    try {
      const url = audioUrl ?? (await requestTtsAudioUrl(tibetanText))
      if (url) {
        audioRef.current ??= new Audio()
        audioRef.current.src = url
        await audioRef.current.play()
        setState('playing')
        audioRef.current.onended = () => setState('idle')
        return
      }
      if ('speechSynthesis' in window) {
        const utterance = new SpeechSynthesisUtterance(tibetanText)
        utterance.lang = 'bo'
        utterance.onend = () => setState('idle')
        window.speechSynthesis.speak(utterance)
        setState('playing')
        return
      }
      setState('error')
    } catch {
      setState('error')
    }
  }, [tibetanText, audioUrl])

  return { play, state }
}
