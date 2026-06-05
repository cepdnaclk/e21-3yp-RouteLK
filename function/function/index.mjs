import { CognitoIdentityProviderClient, ConfirmSignUpCommand } from "@aws-sdk/client-cognito-identity-provider";
import pkg from 'pg';
const { Pool } = pkg;

const cognito = new CognitoIdentityProviderClient({ region: 'eu-north-1' });

export const handler = async (event) => {
  try {
    const { email, otp } = JSON.parse(event.body);

    await cognito.send(new ConfirmSignUpCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: email,
      ConfirmationCode: otp
    }));

    const pool = new Pool({ connectionString: process.env.DB_URL });
    await pool.query(
      `UPDATE admins SET is_verified = TRUE WHERE email = $1`,
      [email]
    );
    await pool.end();

    return {
      statusCode: 200,
      headers: { "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify({ message: 'Verified! Login successful' })
    };
  } catch (err) {
    return {
      statusCode: 400,
      headers: { "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify({ message: err.message })
    };
  }
};