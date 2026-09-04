# PLAYBOOK — "Waya" (working name): Diaspora Remittance App on BMONI Embedded

Hand this whole document to the coding agent as its brief. It is written as instructions to that agent — follow it phase by phase, don't skip the "read the docs" steps, and flag anything that contradicts what's actually in the BMONI docs when you get there.

---

## 0. What we are building, in one paragraph

A mobile app that lets a Nigerian in the diaspora (US-based to start) hold a self-custodied USD wallet, fund it from their US bank account, and send money home to a recipient in Nigeria who holds an NGN wallet and can withdraw straight to any Nigerian bank account. Two user roles, one shared backend, one Flutter codebase (BMONI's SDK and UI kit are Flutter-native). The pitch: instant, self-custodied, low-fee remittance rails, wrapped in an app that never mentions the word "crypto" to the end user — it just feels like a modern Western Union/Wise, but on-chain and instant underneath.

---

## 1. Non-negotiable architecture decision: a backend is required

Do not build this as a pure client-only Flutter app talking directly to the BMONI REST API with an embedded API/secret key. Standard practice for these platforms (and almost certainly true here — verify against `/api-reference/introduction` and the auth section when you read it) is:

- **Client (Flutter app)**: uses `bmoni_embedded_sdk` to provision the on-device wallet, manage the PIN, and produce signatures. Uses `bkey_uikit` + `bmoni_embedded_wallets_cards` for all UI. Never holds the BMONI partner/secret API key.
- **Thin backend (BFF)**: a small Node/Express (or equivalent) service that holds the BMONI secret key and proxies every REST call that needs it — create user, KYC session creation, rail activation, VBA provisioning, transfer proposal creation, offramp calls, webhook receipt. The client calls your backend; your backend calls BMONI.

Confirm this against the docs the moment you start (`/api-reference/introduction`, and any auth/API-keys page linked from it) — if BMONI's model is actually designed for direct client calls with a publishable-style key, simplify accordingly. Don't guess past that point; read it first.

---

## 2. Read before you write a single line of code

Before touching Phase 1, load the full doc index and read these pages in full. Do not paraphrase from memory or from this playbook once you have live access — this playbook was written from a partial crawl of the docs and may be missing exact request/response shapes.

1. `https://bkey.mintlify.app/llms.txt` — full page index, use it to find anything not listed below
2. `/lifecycle` — the six-stage mental model everything else assumes
3. `/quickstart` and `/api-quickstart` — fastest path from zero to a working call
4. `/sdk/introduction`, `/sdk/installation`, `/sdk/configuration`, `/sdk/wallet-provisioning`, `/sdk/pin-management`, `/sdk/signing`, `/sdk/error-handling`
5. `/uikit/introduction`, `/uikit/installation`, `/uikit/design-tokens`, and every page under `/uikit/components/`
6. `/wallets/introduction`, `/wallets/installation`, `/wallets/architecture`, `/wallets/data-contracts`, `/wallets/models`, `/wallets/notifiers`, `/wallets/widgets`
7. `/api-reference/introduction`, `/api-reference/integration-flow`
8. `/api-reference/kyc-usd-requirements`, `/api-reference/usd-vba`
9. `/api-reference/kyc-nga-requirements`, `/api-reference/ngn-rails`
10. `/api-reference/transfers`, `/api-reference/signing`, `/api-reference/rails`
11. `/api-reference/sandbox-test-data`, `/request-test-tokens`
12. `/api-reference/webhooks`, `/api-reference/errors`
13. `/api-reference/supported-regions`

If the agent has web access, fetch these directly. If not, use whatever "load docs into your AI editor" mechanism is described on `/ai-setup` — the docs explicitly support this.

---

## 3. The two user journeys (this is the whole product)

### Journey A — Sender (diaspora, e.g. USA)
1. Sign up, provision wallet, set signing PIN
2. Run Global KYC (`id-and-liveness`) — this is the "USD" KYC path
3. Gate on USD readiness, activate USD onboarding (`POST /onboarding/start-usa`), poll the USD virtual bank account until `active`
4. Fund the wallet via ACH/wire to the issued USD virtual account (sandbox: use test tokens)
5. Add a recipient (a phone number / existing BMONI user, or invite one)
6. Send: create a transfer proposal → approve → sign on-device with the PIN → submit
7. See transfer status update in real time (webhook-driven if possible, poll as fallback)

### Journey B — Recipient (Nigeria)
1. Sign up, provision wallet (shortest KYC path — BVN auto-populates profile, `POST /kyc/activate`, no `sumsubLevelName` needed)
2. Receive funds sent by a Journey-A user into their NGN-holding wallet
3. Withdraw to any Nigerian bank account: verify destination account → register it → offramp

**Open question to resolve while reading `/api-reference/transfers` and `/api-reference/rails`:** does a direct wallet-to-wallet transfer support a USD-holding sender paying into an NGN-holding recipient in one step, or does it require an explicit swap leg (USDB → CNGN) before or during the transfer? Don't assume — the transfers doc explicitly separates "send to another user" from "swap between stablecoins," so this may be two calls, not one. Design the UI so the user only ever sees one action ("Send ₦50,000 to Mum"), and hide the swap/transfer split behind that single button regardless of which way the API actually works.

---

## 4. Scope

### MVP (must ship)
- Sender onboarding: signup → wallet → PIN → USD KYC → USD VBA active
- Recipient onboarding: signup → wallet → PIN → Nigeria KYC
- Fund sender wallet (sandbox test tokens, simulate the ACH deposit per `/request-test-tokens`)
- Add/select a recipient
- Send money end to end (proposal → approve → sign → submit), landing as NGN-spendable balance for the recipient
- Recipient withdraws to a Nigerian bank account (verify → register → offramp)
- Transaction history for both roles using `EmbeddedWalletTransactionsSection`
- Live exchange-rate display on the send screen (USD → NGN), even if it's a static/mock rate for the sandbox demo — label it clearly as indicative
- Push-style in-app status updates on transfer state (sent → processing → delivered → withdrawn)

### Stretch (only after MVP works end to end in sandbox)
- Multiple recipients / saved beneficiaries with nicknames + avatars
- Scheduled/recurring remittances ("send $200 every 1st of the month")
- Sender-side spend card issued against the USD wallet (Cards API)
- Webhook-driven push notifications instead of polling
- Crypto top-up path (`/deposit/supported-assets`, `/deposit/wallet`) as an alternative funding method for senders who already hold USDC

### Explicitly out of scope for this build
- MXN, EUR, LATAM cash rails
- Any region other than USA (sender) / Nigeria (recipient)
- Real production KYC documents — sandbox personas only

---

## 5. Screens (this is where "splendid UI" gets decided)

Build every screen with `bkey_uikit` primitives and the wallet-card/transactions widgets from `bmoni_embedded_wallets_cards` — do not hand-roll buttons, cards, or form fields that the kit already provides. Pull the actual palette/typography from `/uikit/design-tokens` rather than guessing colors.

1. **Splash / role selection** — "Sending money?" vs "Receiving money?" (this is the app's core fork; make it visually distinct, e.g. two large tappable cards with a subtle animated globe/line connecting a US flag chip to a Nigeria flag chip)
2. **Onboarding & KYC flow** — stepper UI, progress indicator, use `InProgressWidget`/loaders during async KYC checks, `BMoniToast` for pass/fail feedback
3. **PIN setup** — use the SDK's PIN gate flow as documented in `/sdk/pin-management`
4. **Home / wallet dashboard** — `EmbeddedWalletCard` front and center showing balance (USD or NGN depending on role), a prominent primary CTA ("Send" for sender, "Withdraw" for recipient), recent activity feed below using `ActivitySectionCard`
5. **Fund wallet (sender)** — show the USD virtual account details (account/routing-style info per `/api-reference/usd-vba`), copy-to-clipboard, "waiting for deposit" state with polling + toast on success
6. **Send money (sender)** — recipient picker (avatar list via `ProfileAvatar`), amount entry with live USD→NGN conversion shown as large `AmountText`, review screen, PIN-to-sign step, success state with a satisfying confirmation animation
7. **Add recipient (sender)** — search/invite by phone, show recipient's KYC/verification badge once linked
8. **Withdraw to bank (recipient)** — bank account entry with the verify step showing the resolved account name back to the user before they confirm (standard trust pattern for NG bank transfers), then register + offramp, with clear status states
9. **Transaction history (both roles)** — `EmbeddedWalletTransactionsSection`, filterable by type (funded / sent / received / withdrawn)
10. **Settings/profile** — KYC status, linked bank/recipient info, PIN reset

Design direction: warm, human, "sending money home" emotional tone — not a generic fintech/crypto look. Lean on real currency symbols (₦ / $), recipient names and avatars front and center over wallet addresses, and hide all blockchain/wallet-address language from the end user entirely unless they dig into "advanced" details.

---

## 6. Data model (backend)

- `User` — id, role (sender/recipient), BMONI user id, phone, KYC status, country
- `Wallet` — BMONI wallet id, owner user id, currency (USDB/CNGN), last known balance (cached, not source of truth)
- `Recipient` — sender's saved link to a recipient User, nickname
- `Transfer` — proposal id, sender wallet, recipient wallet, source amount/currency, dest amount/currency, status, timestamps, related bank withdrawal id if applicable
- `WebhookEvent` — raw event log for anything BMONI pushes, per `/api-reference/webhooks`

---

## 7. Build phases (do them in this order — each depends on the last)

**Phase 0 — Environment**
- Get sandbox/test API keys from the docs (test keys are provided per the docs' intro)
- Request sandbox test tokens per `/request-test-tokens` (send the signup phone number; NGN 1,000 and USD 10 get credited)
- Stand up the backend skeleton with the secret key stored server-side only
- Flutter app skeleton with `bmoni_embedded_sdk`, `bkey_uikit`, `bmoni_embedded_wallets_cards` installed per their install pages

**Phase 1 — Wallet + PIN, both roles**
- User signup on your backend → create BMONI user
- Provision on-device wallet via SDK
- Set signing PIN
- Confirm you can read wallet balance/state back through the wallet-cards package notifiers

**Phase 2 — KYC**
- Sender: Global KYC (`id-and-liveness`) using sandbox identity values from `/api-reference/sandbox-test-data`
- Recipient: Nigeria KYC via BVN, `POST /kyc/activate`
- Surface real status states in the UI (pending/approved/rejected) — don't fake a single "done" state

**Phase 3 — Rail activation + funding**
- Sender: gate on `GET /kyc/usd-readiness`, `POST /onboarding/start-usa`, poll `GET /vba/usd` until active, display account details, simulate a deposit with sandbox test tokens
- Recipient: confirm their NGN virtual account is live (per the Nigeria rail docs)

**Phase 4 — Money movement**
- Build the recipient-linking flow
- Build the send flow: proposal → approve → sign (client-side via SDK, per `/api-reference/signing` and `/sdk/signing`) → submit
- Resolve the cross-currency question flagged in Section 3 and implement whichever call sequence the docs actually specify
- Build the recipient withdrawal flow: verify destination bank account → register → offramp (per `/api-reference/ngn-rails`)

**Phase 5 — History, status, polish**
- Transaction history both sides using the prebuilt widget
- Webhook receiver on the backend (`/api-reference/webhooks`) driving status updates to the client (poll as a fallback if webhooks are too heavy for the demo timeline)
- Empty states, error states (map to `/api-reference/errors`), loading states — all via `bkey_uikit` feedback components, not custom spinners

**Phase 6 — Demo readiness**
- Seed two sandbox accounts (one sender, one recipient) fully through KYC and rail activation ahead of time so the live demo skips waiting on async approval
- Rehearse the exact tap sequence: fund → send → withdraw, under 60 seconds end to end
- Have a fallback recorded screen-capture in case sandbox latency or network conditions misbehave live

---

## 8. Definition of done (MVP)

A person can, without touching a backend console: create a sender account in the app, get through USD KYC, fund the wallet with test tokens, add a recipient, send an amount that appears in the recipient's NGN wallet, and have the recipient withdraw it to a Nigerian bank account — all inside the app, all using BMONI's SDK/API, all styled with `bkey_uikit`.

---

## 9. Things the agent must not do

- Do not hardcode or assume exact request/response JSON shapes not yet confirmed from the live docs — read the actual page before implementing that call.
- Do not put the BMONI secret API key in the Flutter client.
- Do not skip the PIN-signing step for transfers — it's the security model of the whole product; faking it defeats the point of the demo.
- Do not build custom UI components that duplicate something already in `bkey_uikit` — check the component list first.
