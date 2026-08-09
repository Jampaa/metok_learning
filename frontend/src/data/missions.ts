import type { Mission } from '../types'

/**
 * Developer-defined hunt categories — matches backend/scripts/seed_firestore.py's
 * MISSIONS. Any discovered item whose category matches counts, regardless
 * of which specific word it is (covers "similar items should count").
 */
export const missions: Mission[] = [
  {
    id: 'stationery-hunt',
    title: 'Find 3 Stationery Items',
    description: 'Pens, books, paper — school supplies of any kind!',
    targetCategory: 'stationery',
    requiredCount: 3,
    reward: 50,
    badge: 'Scribe Badge',
  },
  {
    id: 'kitchen-hunt',
    title: 'Find 3 Kitchen Items',
    description: 'Anything you’d find in the kitchen!',
    targetCategory: 'kitchen',
    requiredCount: 3,
    reward: 50,
    badge: 'Kitchen Badge',
  },
  {
    id: 'house-hunt',
    title: 'Find 3 House Items',
    description: 'Furniture and things around the house!',
    targetCategory: 'house',
    requiredCount: 3,
    reward: 40,
    badge: 'House Badge',
  },
]
