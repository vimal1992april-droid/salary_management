import { useEffect, useState } from 'react'
import { getHealth, type Health } from './api/health'

function App() {
  const [health, setHealth] = useState<Health | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    getHealth()
      .then(setHealth)
      .catch((err: Error) => setError(err.message))
  }, [])

  return (
    <main>
      <h1>Salary Management</h1>
      {error && <p>API unreachable: {error}</p>}
      {!error && !health && <p>Checking API…</p>}
      {health && (
        <p>
          API {health.status} · Rails {health.rails} · database {health.database ? 'connected' : 'down'}
        </p>
      )}
    </main>
  )
}

export default App
