import { CognitoIdentityProviderClient, ConfirmSignUpCommand } from "@aws-sdk/client-cognito-identity-provider";
import pkg from 'pg';
const { Pool } = pkg;

const cognito = new CognitoIdentityProviderClient({ region: 'eu-north-1' });
const CLIENT_ID = '2p4uncisd6lr431vvq3fdkhj0n'; // same client ID

export const handler = async (event) => {
  const { email, otp } = JSON.parse(event.body);

  // 1. Verify OTP with Cognito
  await cognito.send(new ConfirmSignUpCommand({
    ClientId: CLIENT_ID,
    Username: email,
    ConfirmationCode: otp
  }));

  // 2. Mark verified in your DB
  const pool = new Pool({ connectionString: process.env.DB_URL });
  await pool.query(
    `UPDATE admins SET is_verified = TRUE WHERE email = $1`,
    [email]
  );
  await pool.end();

  return {
    statusCode: 200,
    body: JSON.stringify({ message: 'Verified! Login successful' })
  };
};