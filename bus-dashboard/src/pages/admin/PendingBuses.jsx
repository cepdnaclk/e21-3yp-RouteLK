import React, { useEffect, useState } from 'react'
import { getPendingBuses, approveBus, rejectBus } from '../../api'

function ensureSampleData() {
  const existing = JSON.parse(localStorage.getItem('buses') || 'null')
  if (existing) return
  const sample = [
    { id: 'b1', plate: 'WP KA-1234', route: 'Peradeniya - Gampola', ownerId: 'OWN-001', status: 'pending' },
    { id: 'b2', plate: 'WP PB-5678', route: 'Peradeniya - Kurunegala', ownerId: 'OWN-002', status: 'approved' },
    { id: 'b3', plate: 'WP LC-9012', route: 'Peradeniya - Matale', ownerId: 'OWN-003', status: 'pending' },
    { id: 'b4', plate: 'WP XX-3344', route: 'Peradeniya - Gampola', ownerId: 'OWN-004', status: 'approved' },
    { id: 'b5', plate: 'WP ZZ-7788', route: 'Peradeniya - Kandy', ownerId: 'OWN-005', status: 'approved' },
    { id: 'b6', plate: 'WP YT-1122', route: 'Peradeniya - Gampola', ownerId: 'OWN-006', status: 'pending' },
  ]
  localStorage.setItem('buses', JSON.stringify(sample))
}

export default function PendingBuses() {
  const [buses, setBuses] = useState([])

  useEffect(() => {
    let mounted = true
    async function load() {
      try {
        const data = await getPendingBuses()
        const list = Array.isArray(data) ? data : (data && data.buses) || []
        if (mounted) {
          setBuses(list)
        }
        return
      } catch (e) {
        // fallback to local sample data below
      }
      ensureSampleData()
      if (mounted) setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
    }
    load()
    return () => { mounted = false }
  }, [])

  const refresh = async () => {
    try {
      const data = await getPendingBuses()
      const list = Array.isArray(data) ? data : (data && data.buses) || []
      return setBuses(list)
    } catch (e) {
      // ignore and fallback
    }
    setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
  }

  const approve = async (bus) => {
    const id = bus.bus_id || bus.id || bus._id
    try {
      await approveBus(id)
    } catch (e) {
      // if API fails, update local storage as fallback
      const all = JSON.parse(localStorage.getItem('buses') || '[]')
      const idx = all.findIndex((b) => (b.id === id) || (b.bus_id === id))
      if (idx !== -1) {
        all[idx].status = 'approved'
        localStorage.setItem('buses', JSON.stringify(all))
      }
    }
    refresh()
  }

  return (
    <div>
      <h2>Pending Busses</h2>
      <p>Approve registered busses below.</p>
      <div style={{ background: '#fff', padding: 12, borderRadius: 8 }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb' }}>
              <th style={{ padding: 8 }}>Plate</th>
              <th style={{ padding: 8 }}>Route</th>
              <th style={{ padding: 8 }}>Owner ID</th>
              <th style={{ padding: 8 }}>Action</th>
            </tr>
          </thead>
          <tbody>
            {buses.filter((b) => b.status === 'pending').map((b) => (
              <tr key={b.id}>
                <td style={{ padding: 8 }}>{b.plate}</td>
                <td style={{ padding: 8 }}>{b.route}</td>
                <td style={{ padding: 8 }}>{b.ownerId}</td>
                <td style={{ padding: 8 }}>
                  <button className="btn primary" onClick={() => approve(b.id)}>Approve</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {buses.filter((b) => b.status === 'pending').length === 0 && <div style={{ padding: 12 }}>No pending busses.</div>}
      </div>
    </div>
  )
}
