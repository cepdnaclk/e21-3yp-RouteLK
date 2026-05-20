import React, { useState } from 'react'
import '../Home.css'

export default function AdminRegister() {
  const [fullName, setFullName] = useState('')
  const [governmentEmail, setGovernmentEmail] = useState('')
  const [idNumber, setIdNumber] = useState('')
  const [employeeNumber, setEmployeeNumber] = useState('')
  const [designation, setDesignation] = useState('')
  const [contactNumber, setContactNumber] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const handleSubmit = (e) => {
    e.preventDefault()
    setError('')
    if (!fullName || !governmentEmail || !idNumber || !employeeNumber || !designation) {
      setError('Please fill all required fields')
      return
    }
    if (password.length < 6) {
      setError('Password should be at least 6 characters')
      return
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match')
      return
    }

    const admins = JSON.parse(localStorage.getItem('admins') || '[]')
    // ensure unique government email
    if (admins.find((a) => a.governmentEmail === governmentEmail)) {
      setError('An account with this government email already exists')
      return
    }

    admins.push({ fullName, governmentEmail, idNumber, employeeNumber, designation, contactNumber, password })
    localStorage.setItem('admins', JSON.stringify(admins))

    setSuccess('Successfully registered admin. Redirecting to login...')
    setTimeout(() => {
      window.location.hash = '#/login'
    }, 1800)
  }

  return (
    <div className="home-dashboard">
      <header className="hd-topbar">
        <div>
          <div className="hd-title">RouteLK</div>
          <div className="hd-sub">Admin Registration</div>
        </div>
      </header>

      <main className="hd-container" style={{ minHeight: 'calc(100vh - 112px)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <section style={{ background: '#fff', padding: 24, borderRadius: 8, width: '100%', maxWidth: 720, boxSizing: 'border-box' }}>
          <h2>Create Admin Account</h2>
          <form onSubmit={handleSubmit}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 12 }}>
              <div>
                <label>Full name</label>
                <input required value={fullName} onChange={(e) => setFullName(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>Government email</label>
                <input required type="email" value={governmentEmail} onChange={(e) => setGovernmentEmail(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>ID number</label>
                <input required value={idNumber} onChange={(e) => setIdNumber(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>Government employee number</label>
                <input required value={employeeNumber} onChange={(e) => setEmployeeNumber(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>Designation</label>
                <input required value={designation} onChange={(e) => setDesignation(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>Contact number</label>
                <input type="tel" value={contactNumber} onChange={(e) => setContactNumber(e.target.value)} placeholder="e.g. +94123456789" style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 12, marginTop: 12 }}>
              <div>
                <label>Password</label>
                <input required type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
              <div>
                <label>Confirm password</label>
                <input required type="password" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} style={{ width: '100%', padding: 8, marginTop:6 }} />
              </div>
            </div>

            {error && <div style={{ color: 'red', marginTop: 12 }}>{error}</div>}
            {success && <div style={{ color: 'green', marginTop: 12 }}>{success}</div>}

            <div style={{ marginTop: 16 }}>
              <button className="btn primary" type="submit">Create account</button>
            </div>
          </form>
        </section>
      </main>
    </div>
  )
}
