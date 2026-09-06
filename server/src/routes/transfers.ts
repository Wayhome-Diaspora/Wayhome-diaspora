import { Router } from 'express';
import { bmoni, BmoniApiError } from '../config/bmoni.js';

const router = Router();

// --- Recipient linking ---

/// GET /api/v1/users/:userId/recipients — list linked recipients
router.get('/:userId/recipients', async (req, res) => {
  // For now, recipients are tracked via BMONI user lookups
  // In a real app, you'd store these in a database
  res.json({ recipients: [] });
});

/// POST /api/v1/users/:userId/recipients — link a recipient by phone or user ID
router.post('/:userId/recipients', async (req, res) => {
  try {
    const { phone, bmoniUserId } = req.body;
    // Look up the recipient user
    if (bmoniUserId) {
      // Verify the user exists by checking their wallets
      const wallets = await bmoni.get(
        `/v1/users/${bmoniUserId}/smart-wallets/account/wallets`,
      );
      res.json({
        bmoniUserId,
        wallets,
        linked: true,
      });
    } else {
      res.status(400).json({ error: 'Provide bmoniUserId to link a recipient' });
    }
  } catch (err) {
    handleError(res, err);
  }
});

// --- Transfers ---

/// POST /api/v1/users/:userId/smart-wallets/account/send — create transfer proposal (server picks wallet)
router.post('/:userId/smart-wallets/account/send', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/account/send`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/:walletId/proposals — create proposal
router.post('/:userId/smart-wallets/:walletId/proposals', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/${req.params.walletId}/proposals`,
      req.body,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/smart-wallets/proposals/:proposalId — read proposal status
router.get('/:userId/smart-wallets/proposals/:proposalId', async (req, res) => {
  try {
    const result = await bmoni.get(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}`,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/proposals/:proposalId/approve — approve proposal
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

/// GET /api/v1/users/:userId/smart-wallets/proposals/:proposalId/sign-payload — get signing payload
router.get('/:userId/smart-wallets/proposals/:proposalId/sign-payload', async (req, res) => {
  try {
    const result = await bmoni.get(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}/sign-payload`,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/smart-wallets/proposals/:proposalId/sign — submit signature
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

/// POST /api/v1/users/:userId/smart-wallets/proposals/:proposalId/reject — reject proposal
router.post('/:userId/smart-wallets/proposals/:proposalId/reject', async (req, res) => {
  try {
    const result = await bmoni.post(
      `/v1/users/${req.params.userId}/smart-wallets/proposals/${req.params.proposalId}/reject`,
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
