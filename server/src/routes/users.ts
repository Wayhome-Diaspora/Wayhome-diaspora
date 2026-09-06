import { Router } from 'express';
import { bmoni, BmoniApiError } from '../config/bmoni.js';
import { userStore } from '../store.js';

const router = Router();

/// POST /api/v1/users — Create a new BMONI user with local role tagging
router.post('/', async (req, res) => {
  try {
    const { role, ...bmoniPayload } = req.body;
    const user = await bmoni.post('/v1/users', bmoniPayload);
    const bmoniUserId = (user as any).bmoniUserId || (user as any).id;

    // Tag role locally (sender or recipient)
    if (role && bmoniUserId) {
      userStore.create({
        bmoniUserId,
        role: role as 'sender' | 'recipient',
        firstName: bmoniPayload.firstName || '',
        lastName: bmoniPayload.lastName || '',
        email: bmoniPayload.email || '',
        phone: bmoniPayload.phoneNumber || '',
      });
    }

    res.json(user);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/local/:bmoniUserId — Get local user info (role, etc.)
router.get('/local/:bmoniUserId', async (req, res) => {
  const localUser = userStore.getByBmoniId(req.params.bmoniUserId);
  if (!localUser) {
    return res.status(404).json({ error: 'Local user not found' });
  }
  res.json(localUser);
});

/// PATCH /api/v1/users/:userId/kyc — Submit KYC profile
router.patch('/:userId/kyc', async (req, res) => {
  try {
    const result = await bmoni.patch(`/v1/users/${req.params.userId}/kyc`, req.body);
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/owner-proof-challenges
router.post('/:userId/smart-wallets/owner-proof-challenges', async (req, res) => {
  try {
    const challenge = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/owner-proof-challenges`,
      req.body,
    );
    res.json(challenge);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/create-managed
router.post('/:userId/smart-wallets/create-managed', async (req, res) => {
  try {
    const wallet = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/create-managed`,
      req.body,
    );
    res.json(wallet);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/onboarding/status
router.get('/:userId/onboarding/status', async (req, res) => {
  try {
    const status = await bmoni.get(`/v1/users/${req.params.userId}/onboarding/status`);
    res.json(status);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/onboarding/start-nigeria
router.post('/:userId/onboarding/start-nigeria', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/onboarding/start-nigeria`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/onboarding/start-usa
router.post('/:userId/onboarding/start-usa', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/onboarding/start-usa`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/usd-readiness
router.get('/:userId/kyc/usd-readiness', async (req, res) => {
  try {
    const readiness = await bmoni.get(`/v1/users/${req.params.userId}/kyc/usd-readiness`);
    res.json(readiness);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/readiness
router.get('/:userId/kyc/readiness', async (req, res) => {
  try {
    const readiness = await bmoni.get(`/v1/users/${req.params.userId}/kyc/readiness`);
    res.json(readiness);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/kyc/activate
router.post('/:userId/kyc/activate', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/kyc/activate`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/vba/usd — USD virtual bank account status
router.get('/:userId/vba/usd', async (req, res) => {
  try {
    const vba = await bmoni.get(`/v1/users/${req.params.userId}/vba/usd`);
    res.json(vba);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/smart-wallets/account/wallets
router.get('/:userId/smart-wallets/account/wallets', async (req, res) => {
  try {
    const wallets = await bmoni.get(`/v1/users/${req.params.userId}/smart-wallets/account/wallets`);
    res.json(wallets);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/smart-wallets/account/balances
router.get('/:userId/smart-wallets/account/balances', async (req, res) => {
  try {
    const balances = await bmoni.get(`/v1/users/${req.params.userId}/smart-wallets/account/balances`);
    res.json(balances);
  } catch (err) {
    handleError(res, err);
  }
});

// --- NGN deposit accounts ---

/// GET /api/v1/users/:userId/bank-accounts/deposit-accounts/NGN
router.get('/:userId/bank-accounts/deposit-accounts/NGN', async (req, res) => {
  try {
    const accounts = await bmoni.get(`/v1/users/${req.params.userId}/bank-accounts/deposit-accounts/NGN`);
    res.json(accounts);
  } catch (err) {
    handleError(res, err);
  }
});

// --- Transfers ---

/// POST /api/v1/users/:userId/smart-wallets/:walletId/proposals
router.post('/:userId/smart-wallets/:walletId/proposals', async (req, res) => {
  try {
    const proposal = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/${req.params.walletId}/proposals`,
      req.body,
    );
    res.json(proposal);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/proposals/:proposalId/approve
router.post('/:userId/smart-wallets/proposals/:proposalId/approve', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}/approve`,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/smart-wallets/proposals/:proposalId/sign-payload
router.get('/:userId/smart-wallets/proposals/:proposalId/sign-payload', async (req, res) => {
  try {
    const payload = await bmoni.get(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}/sign-payload`,
    );
    res.json(payload);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/proposals/:proposalId/sign
router.post('/:userId/smart-wallets/proposals/:proposalId/sign', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}/sign`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

// --- NGN withdrawal ---

/// POST /api/v1/users/:userId/bank-accounts/verify-nigerian-account
router.post('/:userId/bank-accounts/verify-nigerian-account', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/bank-accounts/verify-nigerian-account`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/bank-accounts/withdrawal-accounts/nigeria
router.post('/:userId/bank-accounts/withdrawal-accounts/nigeria', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/bank-accounts/withdrawal-accounts/nigeria`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/:walletId/offramp/nigeria
router.post('/:userId/smart-wallets/:walletId/offramp/nigeria', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/${req.params.walletId}/offramp/nigeria`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

// --- Error handler ---
function handleError(res: any, err: unknown) {
  if (err instanceof BmoniApiError) {
    res.status(err.statusCode).json({ error: err.bmoniMessage });
  } else {
    console.error('Unexpected error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
}

export default router;
