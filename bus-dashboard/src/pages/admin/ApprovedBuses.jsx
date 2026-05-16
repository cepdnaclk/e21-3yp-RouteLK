import React, { useEffect, useState } from 'react'

export default function ApprovedBuses() {
  const [buses, setBuses] = useState([])

  useEffect(() => {
    setBuses(JSON.parse(localStorage.getItem('buses') || '[]'))
  }, [])

  const remove = (id) => {
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
              <tr key={b.id}>
                <td style={{ padding: 8 }}>{b.plate}</td>
                <td style={{ padding: 8 }}>{b.route}</td>
                <td style={{ padding: 8 }}>{b.ownerId}</td>
                <td style={{ padding: 8 }}>
                  <button className="btn outline" onClick={() => remove(b.id)}>Remove</button>
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
