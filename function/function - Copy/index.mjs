import { CognitoIdentityProviderClient, SignUpCommand } from "@aws-sdk/client-cognito-identity-provider";
import pkg from 'pg';
const { Pool } = pkg;

const cognito = new CognitoIdentityProviderClient({ region: 'eu-north-1' });

export const handler = async (event) => {
  try {
    const { name, email, password } = JSON.parse(event.body);

    // Register in Cognito — sends OTP email automatically
    await cognito.send(new SignUpCommand({
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: email,
      Password: password,
      UserAttributes: [
        { Name: 'email', Value: email },
        { Name: 'name', Value: name }
      ]
    }));

    // Save to DB as unverified
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
      headers: { "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify({ message: 'OTP sent to your email' })
    };
  } catch (err) {
    return {
      statusCode: 400,
      headers: { "Access-Control-Allow-Origin": "*" },
      body: JSON.stringify({ message: err.message })
    };
  }
};