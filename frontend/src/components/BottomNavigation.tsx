import { NavLink } from 'react-router-dom'

const items = [
  { to: '/home', label: 'Home', icon: '🏠' },
  { to: '/learn', label: 'Learn', icon: '📚' },
  { to: '/games', label: 'Games', icon: '🎮' },
  { to: '/nfc', label: 'NFC', icon: '📡' },
  { to: '/profile', label: 'Profile', icon: '👤' },
]

export function BottomNavigation() {
  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-40 flex justify-around border-t-2 border-cream-dark bg-white pt-2"
      style={{ paddingBottom: 'env(safe-area-inset-bottom, 0.5rem)' }}
    >
      {items.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) =>
            `flex min-w-16 flex-col items-center gap-0.5 rounded-2xl px-3 py-1.5 text-xs font-bold ${
              isActive ? 'text-primary' : 'text-ink/50'
            }`
          }
        >
          <span className="text-2xl">{item.icon}</span>
          {item.label}
        </NavLink>
      ))}
    </nav>
  )
}
