import { Router } from 'express';
import { bmoni, BmoniApiError } from '../config/bmoni.js';

const router = Router();

/// GET /api/v1/users/:userId/bank-accounts/nigerian-banks — list supported banks
router.get('/:userId/bank-accounts/nigerian-banks', async (req, res) => {
  try {
    const banks = await bmoni.get(`/v1/users/${req.params.userId}/bank-accounts/nigerian-banks`);
    res.json(banks);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/bank-accounts/verify-nigerian-account — verify account number
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

/// POST /api/v1/users/:userId/bank-accounts/withdrawal-accounts/nigeria — register withdrawal account
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

/// POST /api/v1/users/:userId/smart-wallets/:walletId/offramp/nigeria — create offramp proposal
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
