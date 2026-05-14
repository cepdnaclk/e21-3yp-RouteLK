import { useEffect, useState } from 'react'
import Home from './pages/Home'
import RegisteredBuses from './pages/RegisteredBuses'
import './App.css'

function App() {
  const [route, setRoute] = useState(() => window.location.hash || '#/')

  useEffect(() => {
    const onHash = () => setRoute(window.location.hash || '#/')
    window.addEventListener('hashchange', onHash)
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  if (route.startsWith('#/registered')) return <RegisteredBuses />
  return <Home />
}

export default App
