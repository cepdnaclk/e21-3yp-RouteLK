// POST /admin/register
const mysql = require('mysql2/promise');
const AWS = require('aws-sdk');
const ses = new AWS.SES();

exports.handler = async (event) => {
  const { name, email, password } = JSON.parse(event.body);

  const otp = Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP
  const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 min expiry

  const conn = await mysql.createConnection(process.env.DB_URL);

  // Save admin + OTP to DB
  await conn.execute(
    `INSERT INTO admins (name, email, password, otp, otp_expires_at, is_verified)
     VALUES (?, ?, ?, ?, ?, FALSE)`,
    [name, email, password, otp, expires]
  );

  // Send OTP via SES
  await ses.sendEmail({
    Source: 'no-reply@yourdomain.com',
    Destination: { ToAddresses: [email] },
    Message: {
      Subject: { Data: 'Your Admin Verification Code' },
      Body: { Text: { Data: `Your OTP is: ${otp}. Valid for 10 minutes.` } }
    }
  }).promise();

  await conn.end();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'OTP sent to your email' })
  };
};