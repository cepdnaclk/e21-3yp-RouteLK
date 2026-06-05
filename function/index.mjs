const { Pool } = require('pg');

exports.handler = async (event) => {
  const { email, otp } = JSON.parse(event.body);

  const pool = new Pool({ connectionString: process.env.DB_URL });

  const result = await pool.query(
    `SELECT * FROM admins 
     WHERE email = $1 
     AND otp = $2 
     AND otp_expires_at > NOW() 
     AND is_verified = FALSE`,
    [email, otp]
  );

  if (result.rows.length === 0) {
    await pool.end();
    return {
      statusCode: 400,
      body: JSON.stringify({ message: 'Invalid or expired OTP' })
    };
  }

  await pool.query(
    `UPDATE admins 
     SET is_verified = TRUE, otp = NULL, otp_expires_at = NULL 
     WHERE email = $1`,
    [email]
  );

  await pool.end();

  return {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Verified! Login successful',
      adminId: result.rows[0].id,
      name: result.rows[0].name,
      email: result.rows[0].email
    })
  };
};