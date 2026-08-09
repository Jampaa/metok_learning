import type { VocabularyItem } from '../types'

/**
 * OFFLINE-DEMO FALLBACK ONLY. Real usage no longer curates vocabulary —
 * routes/discovery.py discovers + caches words dynamically via Monlam's
 * dictionary the first time each one is scanned (see docs/architecture.md).
 * This file exists solely so the app is fully demoable with zero backend
 * configured (services/api.ts's mockRecognize() picks randomly from here).
 *
 * `verified: true` entries are translations confirmed via a real Monlam
 * dictionary + LLM sense-check call (tested directly against the live API
 * while building this). `verified: false` + `tibetan: 'TODO_VERIFY'` are
 * genuinely unconfirmed — never flip that without actually checking.
 */
export const vocabulary: VocabularyItem[] = [
  { id: 'pen', english: 'pen', tibetan: 'སྨྱུ་གུ', verified: true, category: 'stationery', difficulty: 1, emoji: '✏️', sentences: [{ english: 'I have a pen.', tibetan: 'ང་ལ་སྨྱུ་གུ་ཡོད།' }] },
  { id: 'book', english: 'book', tibetan: 'དེབ', verified: true, category: 'stationery', difficulty: 1, emoji: '✏️', sentences: [] },
  { id: 'paper', english: 'paper', tibetan: 'ཤོག་བུ', verified: true, category: 'stationery', difficulty: 1, emoji: '✏️', sentences: [] },
  { id: 'notebook', english: 'notebook', tibetan: 'ཟིན་དེབ', verified: true, category: 'stationery', difficulty: 1, emoji: '✏️', sentences: [] },
  { id: 'table', english: 'table', tibetan: 'གསོལ་ལྕོག', verified: true, category: 'house', difficulty: 2, emoji: '🛋️', sentences: [] },
  { id: 'chair', english: 'chair', tibetan: 'རྐུབ་ཀྱག', verified: true, category: 'house', difficulty: 2, emoji: '🛋️', sentences: [] },
  { id: 'sofa', english: 'sofa', tibetan: 'ནེམ་ཁྲིའུ', verified: true, category: 'house', difficulty: 2, emoji: '🛋️', sentences: [] },
  { id: 'spoon', english: 'spoon', tibetan: 'ཐུར་མ', verified: true, category: 'kitchen', difficulty: 1, emoji: '🍽️', sentences: [] },
  { id: 'plate', english: 'plate', tibetan: 'སྡེར་རྩེ', verified: true, category: 'kitchen', difficulty: 1, emoji: '🍽️', sentences: [] },
  { id: 'mug', english: 'mug', tibetan: 'མོག', verified: true, category: 'kitchen', difficulty: 1, emoji: '🍽️', sentences: [] },
  { id: 'pencil', english: 'pencil', tibetan: 'TODO_VERIFY', verified: false, category: 'stationery', difficulty: 1, emoji: '✏️', sentences: [] },
  { id: 'ruler', english: 'ruler', tibetan: 'TODO_VERIFY', verified: false, category: 'stationery', difficulty: 2, emoji: '✏️', sentences: [] },
  { id: 'eraser', english: 'eraser', tibetan: 'TODO_VERIFY', verified: false, category: 'stationery', difficulty: 2, emoji: '✏️', sentences: [] },
  { id: 'bag', english: 'bag', tibetan: 'TODO_VERIFY', verified: false, category: 'house', difficulty: 1, emoji: '🛋️', sentences: [] },
]

export const getVocabularyByEnglish = (english: string): VocabularyItem | undefined =>
  vocabulary.find((v) => v.english.toLowerCase() === english.toLowerCase())

export const getVocabularyById = (id: string): VocabularyItem | undefined =>
  vocabulary.find((v) => v.id === id)
