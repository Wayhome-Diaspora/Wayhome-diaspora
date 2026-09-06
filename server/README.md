# Waya Server

Backend BFF (Backend For Frontend) for the Waya remittance app.
Proxies all BMONI API calls — the secret key never touches the Flutter client.

## Environment Variables

Set these in your Freebuff Settings → Environment:

| Variable | Required | Description |
|---|---|---|
| `BMONI_API_KEY` | Yes | BMONI sandbox API key. Shared sandbox key from docs: `pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4` |
| `BMONI_BASE_URL` | No | BMONI API base URL. Defaults to `https://embedded-dev.bmoni.com` (sandbox) |
| `PORT` | No | Server port. Defaults to `3000` |

## Development

```bash
npm install
npm run dev
```

## Architecture

The Flutter app → Waya Server → BMONI API.
The BMONI secret key is stored only on the server, never in the client.
