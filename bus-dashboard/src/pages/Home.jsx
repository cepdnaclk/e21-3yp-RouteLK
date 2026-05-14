import React, { useEffect, useState } from 'react'
import './Home.css'

// Bus and passenger related images (Unsplash)
const images = [
    'bus1.jpg',
    'bus2.jpg',
    'bus4.jpeg',
  
]

export default function Home() {
  const [idx, setIdx] = useState(0)

  useEffect(() => {
    const t = setInterval(() => setIdx((i) => (i + 1) % images.length), 3500)
    return () => clearInterval(t)
  }, [])

  const features = [
    { title: 'Bus Tracking', desc: 'Real-time location of buses on a map.' },
    { title: 'Estimate Arrival Time', desc: 'Accurate ETAs for each stop.' },
    { title: 'Easy Bus Booking', desc: 'Quick tickets and seat reservations.' },
    { title: 'Know Emergencies', desc: 'Alerts and quick-response contacts.' },
  ]

  return (
    <div className="home-dashboard">
      <header className="hd-topbar">
        <div>
          <div className="hd-title">RouteLK</div>
          <div className="hd-sub">Public Transit Operations</div>
        </div>
      </header>

      <nav className="hd-tabs" aria-label="Primary">
        <a className="hd-tab" href="#">Bus Registrations</a>
        <a className="hd-tab" href="#">Admin Dashboard</a>
        <a className="hd-tab" href="#">About Us</a>
        <a className="hd-tab hd-tab-cta" href="#">Login</a>
      </nav>

      <main className="hd-container">
        <section className="hd-hero">
          <img src={images[idx]} alt="hero" className="hd-hero-img" />
          <div className="hd-hero-overlay">
            <h1>Efficient routes. Safer journeys.</h1>
            <p>Manage buses and passengers from a single dashboard.</p>
          </div>
        </section>

        <section className="hd-features">
          {features.map((f) => (
            <div className="hd-feature-card" key={f.title}>
              <div className="hd-feature-title">{f.title}</div>
              <div className="hd-feature-desc">{f.desc}</div>
            </div>
          ))}
        </section>

        <section className="hd-about">
          <h2>About Us</h2>
          <div className="hd-about-grid">
            <img
              src="uop.jpg"
              alt="Team"
            />
            <div className="hd-about-text">
              <h3>Our Team</h3>
              <p>
                We are undergraduate engineering students from the University of
                Peradeniya. This project is developed as part of our initiative to
                improve public transport systems in Sri Lanka.
              </p>
              <h4>Our Vision</h4>
              <p>
                To provide safe, reliable, and accessible transportation for people
                across Sri Lanka by leveraging simple and effective digital tools.
              </p>
            </div>
          </div>
        </section>
        <section className="hd-contact" aria-label="Contact">
          <div className="hd-contact-inner">
            <h3>Contact Us</h3>
            <p>
              Email: <a href="mailto:info@routelk.lk">info@routelk.lk</a> | <a href="mailto:support@routelk.lk">support@routelk.lk</a>
            </p>
            <p>Phone: +94 77 123 4567</p>
            <p>Address: University of Peradeniya, Peradeniya, Sri Lanka</p>
          </div>
        </section>
      </main>
    </div>
  )
}
