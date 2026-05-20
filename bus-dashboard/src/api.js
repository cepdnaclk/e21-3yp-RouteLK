const API = import.meta.env.VITE_API_URL || 'https://grcwv997gb.execute-api.eu-north-1.amazonaws.com/prod';

// ── Auth ──────────────────────────────────────────

export async function adminLogin(government_email, password) {
  const res = await fetch(`${API}/admin/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ government_email, password_hash: password }),
    mode: 'cors',
  });
  return handleResponse(res);
}

export async function adminRegister(adminData) {
  const res = await fetch(`${API}/admin/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(adminData),
    mode: 'cors',
  });
  return handleResponse(res);
}

// ── Bus Management ────────────────────────────────

export async function getPendingBuses() {
  const url = `${API}/buses/pending`
  console.debug('[api] GET', url)
  const res = await fetch(url, { mode: 'cors' });
  let data = await handleResponse(res)
  console.debug('[api] response', url, res.status, data)
  // handle API Gateway / Lambda proxy wrappers (body as string)
  if (data && typeof data.body === 'string') {
    try { data = JSON.parse(data.body) } catch (e) { /* keep original */ }
  }
  return normalizeBuses(data)
}

export async function getApprovedBuses() {
  const url = `${API}/buses/approved`
  console.debug('[api] GET', url)
  const res = await fetch(url, { mode: 'cors' });
  let data = await handleResponse(res)
  console.debug('[api] response', url, res.status, data)
  if (data && typeof data.body === 'string') {
    try { data = JSON.parse(data.body) } catch (e) { /* keep original */ }
  }
  return normalizeBuses(data)
}

export async function approveBus(busId) {
  const res = await fetch(`${API}/buses/approve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ busId }),
    mode: 'cors',
  });
  return handleResponse(res);
}

export async function rejectBus(busId) {
  const res = await fetch(`${API}/buses/reject`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ busId }),
    mode: 'cors',
  });
  return handleResponse(res);
}

async function handleResponse(res) {
  if (res.status === 204) return null;
  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    const txt = await res.text();
    data = txt || null;
  }
  if (!res.ok) {
    const msg = (data && data.message) || res.statusText || 'API error';
    throw new Error(msg);
  }
  return data;
}

function normalizeBuses(data) {
  // data may be an array or an object containing { buses: [...] }
  const arr = Array.isArray(data) ? data : (data && data.buses) || []
  return arr.map((b) => ({
    id: b.id || b.bus_id || b._id || null,
    bus_id: b.bus_id || b.id || b._id || null,
    bus_number: b.bus_number || b.plate || b.number || b.registration || '',
    plate: b.plate || b.bus_number || b.registration || '',
    route: b.route || b.route_name || b.path || '',
    ownerId: b.ownerId || b.owner_nic || b.owner || b.ownerId || '',
    owner_nic: b.owner_nic || b.ownerId || b.owner || '',
    bus_type: b.bus_type || b.type || '',
    total_seats: b.total_seats || b.seats || b.capacity || null,
    status: b.status || b.bus_status || (b.approved ? 'approved' : 'pending') || null,
  }))
}