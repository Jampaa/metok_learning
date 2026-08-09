import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { ProgressProvider } from './hooks/useProgress'
import { BottomNavigation } from './components/BottomNavigation'
import { Welcome } from './pages/Welcome'
import { Home } from './pages/Home'
import { ExplorerScreen } from './features/explorer/ExplorerScreen'
import { WordDetail } from './features/vocabulary/WordDetail'
import { TracingScreen } from './features/tracing/TracingScreen'
import { SentenceQuiz } from './features/sentences/SentenceQuiz'
import { TreasureHuntScreen } from './features/treasure-hunt/TreasureHuntScreen'
import { MissionDetail } from './features/treasure-hunt/MissionDetail'
import { NfcScreen } from './features/nfc/NfcScreen'
import { ProfileScreen } from './features/profile/ProfileScreen'

function Layout() {
  const location = useLocation()
  const hideNav = location.pathname === '/'

  return (
    <div className="mx-auto min-h-screen max-w-md bg-cream">
      <Routes>
        <Route path="/" element={<Welcome />} />
        <Route path="/home" element={<Home />} />
        <Route path="/learn" element={<ExplorerScreen />} />
        <Route path="/learn/word/:id" element={<WordDetail />} />
        <Route path="/learn/word/:id/trace" element={<TracingScreen />} />
        <Route path="/learn/word/:id/practice" element={<SentenceQuiz />} />
        <Route path="/games" element={<TreasureHuntScreen />} />
        <Route path="/games/:missionId" element={<MissionDetail />} />
        <Route path="/nfc" element={<NfcScreen />} />
        <Route path="/profile" element={<ProfileScreen />} />
        <Route path="*" element={<Navigate to="/home" replace />} />
      </Routes>
      {!hideNav && <BottomNavigation />}
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <ProgressProvider>
        <Layout />
      </ProgressProvider>
    </BrowserRouter>
  )
}

export default App
