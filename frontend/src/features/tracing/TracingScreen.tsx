import { useNavigate, useParams } from 'react-router-dom'
import { getVocabularyById } from '../../data/vocabulary'
import { Button } from '../../components/Button'
import { TibetanWord } from '../../components/TibetanWord'
import { useProgress } from '../../hooks/useProgress'
import { useRef, useState } from 'react'

const GRID = 16

/**
 * Basic Uchen tracing per spec Section 18: no handwriting-recognition model,
 * just a coarse "did you draw roughly inside the faded target, and how much
 * of it did you cover" heuristic. Good enough to feel like a game, not a
 * proficiency measurement.
 */
export function TracingScreen() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { progress, logEvent, addStars } = useProgress()
  const item = id ? (progress.discoveredWords[id] ?? getVocabularyById(id)) : undefined

  const canvasRef = useRef<HTMLCanvasElement>(null)
  const targetRef = useRef<HTMLSpanElement>(null)
  const drawing = useRef(false)
  const inZoneCount = useRef(0)
  const outZoneCount = useRef(0)
  const coveredCells = useRef<Set<string>>(new Set())
  const [score, setScore] = useState<number | null>(null)
  const [startedLogged, setStartedLogged] = useState(false)

  if (!item) {
    return (
      <div className="px-5 pt-16 text-center">
        <p className="font-bold">Word not found.</p>
        <Button className="mt-4" onClick={() => navigate('/learn')}>
          Back
        </Button>
      </div>
    )
  }

  const getTargetRect = () => targetRef.current?.getBoundingClientRect()

  const draw = (clientX: number, clientY: number) => {
    const canvas = canvasRef.current
    const targetRect = getTargetRect()
    if (!canvas || !targetRect) return
    const canvasRect = canvas.getBoundingClientRect()
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const x = clientX - canvasRect.left
    const y = clientY - canvasRect.top
    ctx.fillStyle = '#4cad50'
    ctx.beginPath()
    ctx.arc(x, y, 6, 0, Math.PI * 2)
    ctx.fill()

    const inZone =
      clientX >= targetRect.left && clientX <= targetRect.right && clientY >= targetRect.top && clientY <= targetRect.bottom
    if (inZone) {
      inZoneCount.current += 1
      const col = Math.floor(((clientX - targetRect.left) / targetRect.width) * GRID)
      const row = Math.floor(((clientY - targetRect.top) / targetRect.height) * GRID)
      coveredCells.current.add(`${row},${col}`)
    } else {
      outZoneCount.current += 1
    }
  }

  const handleStart = () => {
    drawing.current = true
    if (!startedLogged) {
      logEvent(item.id, 'trace_started')
      setStartedLogged(true)
    }
  }
  const handleMove = (clientX: number, clientY: number) => {
    if (drawing.current) draw(clientX, clientY)
  }
  const handleEnd = () => {
    drawing.current = false
  }

  const clear = () => {
    const canvas = canvasRef.current
    const ctx = canvas?.getContext('2d')
    if (canvas && ctx) ctx.clearRect(0, 0, canvas.width, canvas.height)
    inZoneCount.current = 0
    outZoneCount.current = 0
    coveredCells.current.clear()
    setScore(null)
  }

  const finish = () => {
    const total = inZoneCount.current + outZoneCount.current
    const accuracy = total > 0 ? inZoneCount.current / total : 0
    const coverage = Math.min(1, coveredCells.current.size / (GRID * GRID * 0.3))
    const result = Math.round(70 * accuracy + 30 * coverage)
    setScore(result)
    logEvent(item.id, 'trace_completed', { score: result })
    if (result >= 50) addStars(10)
  }

  return (
    <div className="flex flex-col gap-5 px-5 pb-28 pt-8">
      <div>
        <h1 className="text-xl font-extrabold text-primary-dark">Trace it! ✍️</h1>
        <p className="text-ink/60">Follow the faded word with your finger.</p>
      </div>

      <div className="relative h-64 rounded-3xl bg-white shadow-[0_4px_0_rgba(0,0,0,0.06)]">
        <div className="absolute inset-0 flex items-center justify-center">
          <span ref={targetRef}>
            <TibetanWord text={item.tibetan} verified={item.verified} faded size="xl" />
          </span>
        </div>
        <canvas
          ref={canvasRef}
          width={320}
          height={256}
          className="absolute inset-0 h-full w-full touch-none"
          onPointerDown={(e) => {
            handleStart()
            draw(e.clientX, e.clientY)
          }}
          onPointerMove={(e) => handleMove(e.clientX, e.clientY)}
          onPointerUp={handleEnd}
          onPointerLeave={handleEnd}
        />
      </div>

      {score !== null && (
        <div className="rounded-2xl bg-primary/10 p-4 text-center">
          <p className="text-2xl font-extrabold text-primary-dark">⭐ {score}%</p>
          <p className="text-ink/70">{score >= 50 ? 'Great job!' : 'Nice try — trace again!'}</p>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3">
        <Button variant="ghost" onClick={clear}>
          Clear
        </Button>
        <Button variant="primary" onClick={finish}>
          Done
        </Button>
      </div>

      <Button variant="adventure" onClick={() => navigate(`/learn/word/${item.id}`)}>
        Back to Word
      </Button>
    </div>
  )
}
