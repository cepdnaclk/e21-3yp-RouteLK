import React, { useEffect, useState } from 'react'

function getTopRoutes(buses, top = 5) {
  const counts = {}
  buses.forEach((b) => {
    if (b.status !== 'approved') return
    counts[b.route] = (counts[b.route] || 0) + 1
  })
  const arr = Object.keys(counts).map((r) => ({ route: r, count: counts[r] }))
  arr.sort((a, b) => b.count - a.count)
  return arr.slice(0, top)
}

export default function Analytics() {
  const [buses, setBuses] = useState([])

  useEffect(() => {
    setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
  }, [])

  const top = getTopRoutes(buses)
  const max = top.length ? Math.max(...top.map(t => t.count)) : 1

  return (
    <div>
      <h2>Analytics</h2>
      <p>All registered (approved) busses and top 5 routes by number of busses.</p>

      <div style={{ background: '#fff', padding: 12, borderRadius: 8, marginBottom: 18 }}>
        <h3>Registered Busses</h3>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb' }}>
              <th style={{ padding: 8 }}>Plate</th>
              <th style={{ padding: 8 }}>Route</th>
              <th style={{ padding: 8 }}>Owner ID</th>
            </tr>
          </thead>
          <tbody>
            {buses.filter(b => b.status === 'approved').map(b => (
              <tr key={b.id}>
                <td style={{ padding: 8 }}>{b.plate}</td>
                <td style={{ padding: 8 }}>{b.route}</td>
                <td style={{ padding: 8 }}>{b.ownerId}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div style={{ background: '#fff', padding: 12, borderRadius: 8 }}>
        <h3>Top 5 Routes</h3>
        <div style={{ paddingTop: 8 }}>
          {top.length === 0 && <div>No route data available.</div>}
          {top.map((t) => (
            <div key={t.route} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
              <div style={{ width: 160 }}>{t.route}</div>
              <div style={{ background: '#e6e6e6', height: 18, flex: 1, borderRadius: 6 }}>
                <div style={{ width: `${(t.count / max) * 100}%`, background: '#fbbf24', height: '100%', borderRadius: 6 }} />
              </div>
              <div style={{ width: 40, textAlign: 'right' }}>{t.count}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
