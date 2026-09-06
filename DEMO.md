# Waya Demo Walkthrough

## Prerequisites

Before the demo:
1. Run `node server/scripts/seed-demo.mjs` to pre-create sandbox users
2. Request test tokens from BMONI for both phone numbers (`+2348000000000` and `+2348000000001`)
3. Have the backend running (`cd server && npm run dev`)
4. Have the Flutter app running on a device/emulator

## Exact Tap-by-Tap Sequence

### Part 1: Sender (Bunch Dillon)

| Step | Screen | Action | Expected Result |
|------|--------|--------|-----------------|
| 1 | Splash | Tap "Sending money?" | Navigate to onboarding |
| 2 | Onboarding - Account | Enter: First=Bunch, Last=Dillon, Phone=+2348000000000, Email=bunch@demo.com | — |
| 3 | Onboarding - Account | Tap "Continue" | Navigate to wallet provisioning |
| 4 | Onboarding - Wallet | Wait for "Your wallet is ready" | Wallet address shown |
| 5 | Onboarding - Wallet | Tap "Create wallet" | Navigate to PIN setup |
| 6 | Onboarding - PIN | Enter 6-digit PIN (e.g., 123456) | — |
| 7 | Onboarding - PIN | Confirm PIN | — |
| 8 | Onboarding - PIN | Tap "Set PIN & finish" | Navigate to KYC |
| 9 | KYC - Personal | Enter: DOB=1990-01-15 | — |
| 10 | KYC - Personal | Tap "Continue" | Navigate to address |
| 11 | KYC - Address | Enter: Street=15 Admiralty Way, City=Lagos, State=Lagos, Postal=10001 | — |
| 12 | KYC - Address | Tap "Continue" | Navigate to employment |
| 13 | KYC - Employment | Enter: Status=employed, Source=salary, Volume=5000 | — |
| 14 | KYC - Employment | Tap "Continue" | Navigate to activation |
| 15 | KYC - Activate | Tap "Start verification" | KYC submitted, navigate to home |
| 16 | Home | Wallet card shows balance (initially $0) | — |
| 17 | Home | Tap "Fund" | Navigate to fund screen |
| 18 | Fund | (Sandbox: test tokens auto-credited after request) | Balance updates |
| 19 | Home | Tap "Send" | Navigate to send screen |
| 20 | Send - Recipient | Enter recipient user ID or tap "Samson Jabo" | — |
| 21 | Send - Recipient | Tap "Continue" | Navigate to amount |
| 22 | Send - Amount | Enter amount (e.g., 5000 NGN) | — |
| 23 | Send - Amount | Tap "Review" | Navigate to review |
| 24 | Send - Review | Review details, enter PIN | — |
| 25 | Send - Review | Tap "Send money" | Toast: "Money sent successfully!" |

### Part 2: Recipient (Samson Jabo)

| Step | Screen | Action | Expected Result |
|------|--------|--------|-----------------|
| 1 | Splash | Tap "Receiving money?" | Navigate to onboarding |
| 2 | Onboarding - Account | Enter: First=Samson, Last=Jabo, Phone=+2348000000001 | — |
| 3-8 | (Same as sender) | Account → Wallet → PIN | — |
| 9 | KYC - BVN | Enter BVN: 22222222222 | — |
| 10 | KYC - BVN | Tap "Continue" | BVN verified, name auto-filled |
| 11-12 | KYC - Address | Enter Nigerian address | — |
| 13 | KYC - Activate | Tap "Verify & finish" | KYC submitted, navigate to home |
| 14 | Home | Wallet shows NGN balance (received from sender) | — |
| 15 | Home | Tap "Withdraw" | Navigate to withdraw screen |
| 16 | Withdraw - Bank | Select bank (e.g., Guaranty Trust Bank) | — |
| 17 | Withdraw - Bank | Enter account number: 0123456789 | — |
| 18 | Withdraw - Bank | Tap "Verify account" | Account holder name shown |
| 19 | Withdraw - Amount | Enter amount | — |
| 20 | Withdraw - Amount | Tap "Continue" | Navigate to review |
| 21 | Withdraw - Review | Review details, enter PIN | — |
| 22 | Withdraw - Review | Tap "Withdraw" | Toast: "Withdrawal submitted!" |

## Timing

Expected times (sandbox):
- Account creation: ~2s
- Wallet provisioning: ~1s (on-device, instant)
- KYC activation: ~3-5s (sandbox is fast)
- Fund wallet: instant (sandbox test tokens)
- Send money: ~5-8s (proposal → approve → sign → submit)
- Withdraw: ~5-8s (verify → register → offramp → sign)

**Total demo time: ~60-90 seconds** for the full loop.

## Fragile Points ⚠️

1. **KYC activation latency** — Global KYC (id-and-liveness) may take 3-10s in sandbox. The UI shows a loading spinner. If it takes longer than 10s, something may be wrong.

2. **Transfer proposal polling** — After approving a proposal, we poll for `PENDING_SIGNATURES` status. If the sandbox is slow, this could take 2-3 seconds. The UI shows a loading state.

3. **Exchange rate display** — Currently showing a static indicative rate (1 USD ≈ 1,550 NGN). In production, fetch from `GET /exchange/quote`.

4. **Wallet ID for offramp** — The withdrawal screen uses a placeholder wallet ID. Before the demo, fetch the actual CNGN wallet ID from `GET /smart-wallets/account/wallets`.

5. **Recipient linking** — The send screen accepts a raw user ID. For the demo, pre-link the recipient or use a quick-select button.

## Backup Plan

If sandbox latency misbehaves during the live demo:

1. **Pre-seed accounts** — Run `seed-demo.mjs` before the demo to create users
2. **Pre-fund wallets** — Request test tokens from BMONI ahead of time
3. **Record a screen capture** — Record the full flow on a working device as backup
4. **Have the transaction history ready** — Show a pre-populated transaction list if the live send fails
5. **Keep the backend logs visible** — Show the webhook receiver catching events in real-time

## What Could Go Wrong

| Issue | Likelihood | Mitigation |
|-------|------------|------------|
| BMONI sandbox down | Low | Have a pre-recorded video |
| KYC activation slow | Medium | Show loading state, mention "real-time verification" |
| Transfer fails | Low | Retry once, then show pre-recorded |
| Wallet provisioning fails | Very low | This is on-device, almost never fails |
| Exchange rate wrong | N/A | Show "indicative" label |

## Demo Script (Spoken)

"Let me show you Waya — a remittance app for the African diaspora. 

[Open app]
This is the splash screen. I'm sending money, so I'll tap 'Sending money?'

[Create account]
I'm creating an account as Bunch Dillon — that's our test persona.

[Wallet provisioning]
The app is generating a cryptographic keypair in my phone's secure hardware. This is a self-custodied wallet — no one else holds my keys.

[PIN setup]
I'm setting a 6-digit PIN that protects my signing key.

[KYC]
Now I'm completing identity verification. For USD accounts, this is Global KYC with liveness check — it verifies I'm a real person.

[Home]
Here's my wallet dashboard. I can see my USD balance.

[Fund]
I'm funding my wallet with test tokens from the sandbox.

[Send]
Now I'll send money to Samson in Lagos. I'll enter the amount — 5,000 Naira.

[Review & PIN]
I'm reviewing the details and entering my PIN to authorize the transfer.

[Success]
Money sent! The transfer is now processing on-chain.

[Switch to recipient]
Now let me show you the recipient experience. Samson opens the app and selects 'Receiving money?'

[Recipient KYC]
For Nigerian users, KYC is simpler — just a BVN. It auto-populates the profile.

[Withdraw]
Samson can see the money arrived. He's withdrawing to his GTBank account.

[Verify account]
The app verifies the account and shows the account holder name — 'Samson Jabo' — so he knows it's going to the right place.

[Withdrawal submitted]
Withdrawal submitted! The money will arrive in his bank account within minutes.

[Transaction history]
Both users can see their full transaction history, filtered by type."
