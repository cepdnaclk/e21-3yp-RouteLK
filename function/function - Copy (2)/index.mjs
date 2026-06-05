import pkg from 'pg';
const { Pool } = pkg;

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: 5432,
  ssl: { rejectUnauthorized: false },
});

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type,authorization',
  'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
};

export const handler = async (event) => {
  const httpMethod = event.requestContext?.http?.method || event.httpMethod;
  const path = event.rawPath || event.path;
  const body = event.body ? JSON.parse(event.body) : {};

  console.log('Method:', httpMethod, 'Path:', path);

  // ── CORS preflight ── MUST BE FIRST
  if (httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: CORS_HEADERS, body: '' };
  }

  try {

    if (httpMethod === 'GET' && path === '/prod/buses/pending') {
      const result = await pool.query(
        'SELECT * FROM bus_registration WHERE approved = false ORDER BY created_at DESC'
      );
      return response(200, result.rows);
    }

    if (httpMethod === 'GET' && path === '/prod/buses/approved') {
      const result = await pool.query(
        'SELECT * FROM bus_registration WHERE approved = true ORDER BY created_at DESC'
      );
      return response(200, result.rows);
    }

    if (httpMethod === 'POST' && path === '/prod/buses/approve') {
      const { busId } = body;
      await pool.query(
        'UPDATE bus_registration SET approved = true WHERE bus_id = $1',
        [busId]
      );
      return response(200, { message: 'Bus approved successfully' });
    }

    if (httpMethod === 'POST' && path === '/prod/buses/reject') {
      const { busId } = body;
      await pool.query(
        'DELETE FROM bus_registration WHERE bus_id = $1',
        [busId]
      );
      return response(200, { message: 'Bus rejected successfully' });
    }

    if (httpMethod === 'POST' && path === '/prod/admin/register') {
      const { employee_no, full_name, government_email, designation, password_hash, contact_no } = body;
      await pool.query(
        `INSERT INTO admins (employee_no, full_name, government_email, designation, password_hash, contact_no)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [employee_no, full_name, government_email, designation, password_hash, contact_no]
      );
      return response(200, { message: 'Admin registered successfully' });
    }

    if (httpMethod === 'POST' && path === '/prod/admin/login') {
      const { government_email, password_hash } = body;
      const result = await pool.query(
        'SELECT * FROM admins WHERE government_email = $1 AND password_hash = $2',
        [government_email, password_hash]
      );
      if (result.rows.length === 0) {
        return response(401, { error: 'Invalid email or password' });
      }
      await pool.query(
        'UPDATE admins SET last_login = NOW() WHERE government_email = $1',
        [government_email]
      );
      const admin = result.rows[0];
      return response(200, {
        message: 'Login successful',
        admin: {
          admin_id: admin.admin_id,
          full_name: admin.full_name,
          employee_no: admin.employee_no,
          designation: admin.designation,
          government_email: admin.government_email,
        }
      });
    }

    return response(404, { error: 'Route not found', receivedPath: path, receivedMethod: httpMethod });

  } catch (err) {
    console.error(err);
    return response(500, { error: err.message });
  }
};

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  };
}