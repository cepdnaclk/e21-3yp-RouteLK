import React, { useEffect, useState } from 'react'
import { getApprovedBuses } from '../../api'

export default function ApprovedBuses() {
  const [buses, setBuses] = useState([])

  useEffect(() => {
    let mounted = true
    async function load() {
      try {
        const data = await getApprovedBuses()
        const list = Array.isArray(data) ? data : (data && data.buses) || []
        if (mounted) return setBuses(list)
      } catch (e) {
        // fallback to local storage
      }
      if (mounted) setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
    }
    load()
    return () => { mounted = false }
  }, [])

  const remove = (id) => {
    // No API removal implemented; fall back to local change for now
    const all = JSON.parse(localStorage.getItem('buses') || '[]')
    const filtered = all.filter((b) => b.id !== id)
    localStorage.setItem('buses', JSON.stringify(filtered))
    setBuses(filtered)
  }

  return (
    <div>
      <h2>Registered Busses</h2>
      <p>Approved busses in the system.</p>
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
            {buses.filter((b) => b.status === 'approved').map((b) => (
              <tr key={b.id || b.bus_id}>
                <td style={{ padding: 8 }}>{b.plate || b.bus_number}</td>
                <td style={{ padding: 8 }}>{b.route}</td>
                <td style={{ padding: 8 }}>{b.ownerId || b.owner_nic}</td>
                <td style={{ padding: 8 }}>
                  <button className="btn outline" onClick={() => remove(b.id || b.bus_id)}>Remove</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {buses.filter((b) => b.status === 'approved').length === 0 && <div style={{ padding: 12 }}>No approved busses.</div>}
      </div>
    </div>
  )
}
