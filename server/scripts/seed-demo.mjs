/**
 * Waya Demo Seeder
 * 
 * Seeds two sandbox accounts:
 * 1. Sender (Bunch Dillon) — US-based diaspora user with USD wallet
 * 2. Recipient (Samson Jabo) — Nigeria-based user with NGN wallet
 * 
 * Run: node scripts/seed-demo.mjs
 * 
 * Requires: BMONI_API_KEY and BMONI_BASE_URL in .env.local
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Load env
const __dirname = fileURLToPath(new URL('.', import.meta.url));
try {
  const envContent = readFileSync(resolve(__dirname, '../../.env.local'), 'utf8');
  for (const line of envContent.split('\n')) {
    const [key, ...valueParts] = line.split('=');
    if (key && valueParts.length) {
      process.env[key.trim()] = valueParts.join('=').trim();
    }
  }
} catch {}

const BASE_URL = process.env.BMONI_BASE_URL || 'https://embedded-dev.bmoni.com';
const API_KEY = process.env.BMONI_API_KEY;

if (!API_KEY) {
  console.error('❌ BMONI_API_KEY not found in .env.local');
  process.exit(1);
}

const headers = {
  'x-api-key': API_KEY,
  'Content-Type': 'application/json',
};

async function api(method, path, body) {
  const url = `${BASE_URL}${path}`;
  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);
  
  const res = await fetch(url, opts);
  const text = await res.text();
  
  if (!res.ok) {
    console.error(`  ❌ ${res.status}: ${text.slice(0, 200)}`);
    return null;
  }
  
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

// Sandbox test personas
const SENDER = {
  firstName: 'Bunch',
  lastName: 'Dillon',
  email: 'bunch.dillon@waya-demo.com',
  phoneNumber: '+2348000000000',
  bvn: '95888168924',
  address: {
    streetLine1: '15 Admiralty Way',
    city: 'Lagos',
    state: 'Lagos',
    countryCode: 'USA',
    postalCode: '10001',
  },
  employment: {
    employmentStatus: 'employed',
    sourceOfFunds: 'salary',
    estimatedMonthlyVolume: '5000',
  },
};

const RECIPIENT = {
  firstName: 'Samson',
  lastName: 'Jabo',
  email: 'samson.jabo@waya-demo.com',
  phoneNumber: '+2348000000001',
  bvn: '22222222222',
  address: {
    streetLine1: '15 Admiralty Way',
    city: 'Lagos',
    state: 'Lagos',
    countryCode: 'NGA',
    postalCode: '100001',
  },
};

async function seedSender() {
  console.log('\n👤 Seeding sender account (Bunch Dillon)...');
  
  // 1. Create user
  const user = await api('POST', '/v1/users', {
    firstName: SENDER.firstName,
    lastName: SENDER.lastName,
    email: SENDER.email,
    phoneNumber: SENDER.phoneNumber,
  });
  
  if (!user) return null;
  const userId = user.bmoniUserId || user.id;
  console.log(`  ✅ User created: ${userId}`);
  
  // 2. Submit KYC profile
  await api('PATCH', `/v1/users/${userId}/kyc`, {
    personalInfo: {
      firstName: SENDER.firstName,
      lastName: SENDER.lastName,
      dateOfBirth: '1990-01-15',
      gender: 'male',
    },
    addressDetails: SENDER.address,
    employment: SENDER.employment,
    identificationNumbers: {
      type: 'ssn',
      number: '123-45-6789',
      issuingCountryCode: 'USA',
    },
  });
  console.log('  ✅ KYC profile submitted');
  
  // 3. Note: wallet creation requires on-device SDK
  // In the real app, this happens via BmoniEmbeddedSdk.initWallet()
  // For the demo, the app handles this during onboarding
  
  console.log(`  📋 Sender userId: ${userId}`);
  console.log('  ⏳ Wallet creation + PIN setup + Global KYC activation happens in the app');
  
  return userId;
}

async function seedRecipient() {
  console.log('\n👤 Seeding recipient account (Samson Jabo)...');
  
  // 1. Create user
  const user = await api('POST', '/v1/users', {
    firstName: RECIPIENT.firstName,
    lastName: RECIPIENT.lastName,
    email: RECIPIENT.email,
    phoneNumber: RECIPIENT.phoneNumber,
  });
  
  if (!user) return null;
  const userId = user.bmoniUserId || user.id;
  console.log(`  ✅ User created: ${userId}`);
  
  // 2. Submit KYC profile with BVN
  await api('PATCH', `/v1/users/${userId}/kyc`, {
    personalInfo: {
      firstName: RECIPIENT.firstName,
      lastName: RECIPIENT.lastName,
    },
    addressDetails: RECIPIENT.address,
    identificationNumbers: {
      bvn: RECIPIENT.bvn,
    },
  });
  console.log('  ✅ KYC profile submitted with BVN');
  
  console.log(`  📋 Recipient userId: ${userId}`);
  console.log('  ⏳ Wallet creation + PIN setup + Nigeria onboarding happens in the app');
  
  return userId;
}

async function main() {
  console.log('🌍 Waya Demo Seeder');
  console.log(`   Base URL: ${BASE_URL}`);
  console.log('━'.repeat(50));
  
  const senderId = await seedSender();
  const recipientId = await seedRecipient();
  
  console.log('\n━'.repeat(50));
  console.log('📋 Summary');
  console.log('━'.repeat(50));
  console.log(`Sender:   ${senderId || 'FAILED'} (Bunch Dillon, +2348000000000)`);
  console.log(`Recipient: ${recipientId || 'FAILED'} (Samson Jabo, +2348000000001)`);
  console.log('\nNext steps:');
  console.log('1. Open the app and select "Sending money?"');
  console.log('2. Create account with Bunch Dillon details');
  console.log('3. Complete wallet + PIN setup');
  console.log('4. Complete Global KYC (id-and-liveness)');
  console.log('5. Fund wallet with sandbox test tokens');
  console.log('6. Send money to recipient');
  console.log('\nFor the recipient:');
  console.log('1. Open the app and select "Receiving money?"');
  console.log('2. Create account with Samson Jabo details');
  console.log('3. Complete wallet + PIN setup');
  console.log('4. Complete Nigeria KYC via BVN');
  console.log('5. Withdraw to Nigerian bank account');
}

main().catch(console.error);
