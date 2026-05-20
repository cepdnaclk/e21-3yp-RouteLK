import React, { useEffect, useState } from 'react'
import { getApprovedBuses } from '../../api'

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
    let mounted = true
    async function load() {
      try {
        const data = await getApprovedBuses()
        const list = Array.isArray(data) ? data : (data && data.buses) || []
        if (mounted) return setBuses(list)
      } catch (e) {
        // fallback to local sample data
      }
      const existing = JSON.parse(localStorage.getItem('buses') || 'null')
      if (!existing) {
        const sample = [
          { id: 'b1', plate: 'WP KA-1234', route: 'Peradeniya - Gampola', ownerId: 'OWN-001', status: 'approved' },
          { id: 'b2', plate: 'WP PB-5678', route: 'Peradeniya - Kurunegala', ownerId: 'OWN-002', status: 'approved' },
          { id: 'b3', plate: 'WP LC-9012', route: 'Peradeniya - Matale', ownerId: 'OWN-003', status: 'approved' },
          { id: 'b4', plate: 'WP XX-3344', route: 'Peradeniya - Gampola', ownerId: 'OWN-004', status: 'approved' },
          { id: 'b5', plate: 'WP ZZ-7788', route: 'Peradeniya - Kandy', ownerId: 'OWN-005', status: 'approved' },
          { id: 'b6', plate: 'WP YT-1122', route: 'Peradeniya - Gampola', ownerId: 'OWN-006', status: 'approved' },
        ]
        localStorage.setItem('buses', JSON.stringify(sample))
      }
      if (mounted) setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
    }
    load()
    return () => { mounted = false }
  }, [])

  const top = getTopRoutes(buses)
  const max = top.length ? Math.max(...top.map(t => t.count)) : 1

  const approvedCount = buses.filter(b => b.status === 'approved').length

  return (
    <div>
      <h2>Analytics</h2>
      <p>All registered (approved) busses and top 5 routes by number of busses.</p>

      <div style={{ background: '#fff', padding: 20, borderRadius: 8, marginBottom: 18, display: 'flex', alignItems: 'center', gap: 16 }}>
        <div style={{ flex: '0 0 auto' }}>
          <h3 style={{ margin: 0 }}>Registered Buses</h3>
          <div style={{ fontSize: 26, fontWeight: 700, marginTop: 6 }}>{approvedCount}</div>
          <div style={{ color: '#6b7280', marginTop: 4 }}>{buses.length} total, {approvedCount} approved</div>
        </div>
      </div>

      <div style={{ background: '#fff', padding: 12, borderRadius: 8 }}>
        <h3>Top 5 Routes</h3>
        <div style={{ paddingTop: 8 }}>
          {top.length === 0 && <div>No route data available.</div>}
          {top.length > 0 && (
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 16, height: 220, padding: '12px 8px' }}>
              {top.map((t) => (
                <div key={t.route} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: 80, height: '100%', boxSizing: 'border-box' }}>
                  <div style={{ fontSize: 12, color: '#374151', marginBottom: 6 }}>{t.count}</div>
                  <div style={{ width: '100%', flex: '1 1 auto', display: 'flex', alignItems: 'flex-end' }}>
                    <div style={{ width: '100%', height: `${(t.count / max) * 100}%`, background: '#f59e0b', borderRadius: 4, transition: 'height .3s' }} />
                  </div>
                  <div style={{ marginTop: 8, textAlign: 'center', fontSize: 12, color: '#374151', wordBreak: 'break-word' }}>{t.route}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
