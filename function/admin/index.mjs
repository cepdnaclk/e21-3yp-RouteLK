import { CognitoIdentityProviderClient, SignUpCommand } from "@aws-sdk/client-cognito-identity-provider";
import pkg from 'pg';
const { Pool } = pkg;

const cognito = new CognitoIdentityProviderClient({ region: 'eu-north-1' });
const CLIENT_ID = '2p4uncisd6lr431vvq3fdkhj0n'; // paste your client ID here

export const handler = async (event) => {
  const { name, email, password } = JSON.parse(event.body);

  // 1. Register in Cognito — this sends OTP email automatically
  await cognito.send(new SignUpCommand({
    ClientId: CLIENT_ID,
    Username: email,
    Password: password,
    UserAttributes: [
      { Name: 'email', Value: email },
      { Name: 'name', Value: name }
    ]
  }));

  // 2. Save to your DB (unverified for now)
  const pool = new Pool({ connectionString: process.env.DB_URL });
  await pool.query(
    `INSERT INTO admins (name, email, password, is_verified)
     VALUES ($1, $2, $3, FALSE)
     ON CONFLICT (email) DO NOTHING`,
    [name, email, password]
  );
  await pool.end();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'OTP sent to your email' })
  };
};