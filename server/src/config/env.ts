import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load .env.local first (Freebuff secrets at project root), then .env as fallback
dotenv.config({ path: path.resolve(__dirname, '../../../.env.local') });
dotenv.config();

export const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  bmoni: {
    apiKey: process.env.BMONI_API_KEY!,
    baseUrl: process.env.BMONI_BASE_URL || 'https://embedded-dev.bmoni.com',
    webhookSecret: process.env.BMONI_WEBHOOK_SECRET || '',
  },
} as const;

// Validate required env vars on startup
if (!config.bmoni.apiKey) {
  console.error(
    '❌ BMONI_API_KEY is required. Set it in your .env file.\n' +
    '   Sandbox key from docs: pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4\n' +
    '   Base URL: https://embedded-dev.bmoni.com',
  );
  process.exit(1);
}
