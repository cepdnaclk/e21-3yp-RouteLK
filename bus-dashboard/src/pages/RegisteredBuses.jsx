import React from 'react'
import './Home.css'

const sampleBuses = [
  { plate: 'WP KA-1234', route: 'Peradeniya - Gampola', ownerId: 'OWN-001' },
  { plate: 'WP PB-5678', route: 'Peradeniya - Kurunegala', ownerId: 'OWN-002' },
  { plate: 'WP LC-9012', route: 'Peradeniya - Matale', ownerId: 'OWN-003' },
]

export default function RegisteredBuses() {
  return (
    <div className="home-dashboard">
      <header className="hd-topbar">
        <div>
          <div className="hd-title">RouteLK</div>
          <div className="hd-sub">Track your bus & save your time</div>
        </div>
      </header>

      <nav className="hd-tabs" aria-label="Primary">
        <a className="hd-tab" href="#/">Home</a>
        <a className="hd-tab" href="#/">Admin Dashboard</a>
        <a className="hd-tab" href="#/about">About Us</a>
      </nav>

      <main className="hd-container">
        <section className="hd-registered-intro">
          <p>Registered buses to RouteLK</p>
        </section>

        <section className="hd-registered-table">
          <table className="registered-table">
            <thead>
              <tr>
                <th>Bus Number Plate</th>
                <th>Bus Route</th>
                <th>Bus Owner ID</th>
              </tr>
            </thead>
            <tbody>
              {sampleBuses.map((b) => (
                <tr key={b.plate}>
                  <td>{b.plate}</td>
                  <td>{b.route}</td>
                  <td>{b.ownerId}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </main>
    </div>
  )
}
