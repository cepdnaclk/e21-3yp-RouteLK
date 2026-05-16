import React, { useState } from 'react'
import './Home.css'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    const admins = JSON.parse(localStorage.getItem('admins') || '[]')
    const found = admins.find((a) => a.governmentEmail === email && a.password === password)
    if (!found) {
      setError('Invalid credentials. If you have no account, create one.')
      return
    }
    localStorage.setItem('adminAuth', JSON.stringify({ email: found.governmentEmail, name: found.fullName }))
    window.location.hash = '#/admin'
  }

  return (
    <div className="home-dashboard">
      <header className="hd-topbar">
        <div>
          <div className="hd-title">RouteLK</div>
          <div className="hd-sub">Admin Login</div>
        </div>
      </header>

      <main className="hd-container" style={{ minHeight: 'calc(100vh - 112px)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <section style={{ background: '#fff', padding: 24, borderRadius: 8, width: '100%', maxWidth: 560, boxSizing: 'border-box' }}>
          <h2>Admin Login</h2>
          <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: 12 }}>
              <label>Government Email</label>
              <input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
            </div>
            <div style={{ marginBottom: 12 }}>
              <label>Password</label>
              <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
            </div>
            {error && <div style={{ color: 'red', marginBottom: 12 }}>{error}</div>}
            <div style={{ display: 'flex', gap: 12 }}>
              <button className="btn primary" type="submit">Login</button>
              <a className="btn outline" href="#/admin/register">Create account</a>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}
