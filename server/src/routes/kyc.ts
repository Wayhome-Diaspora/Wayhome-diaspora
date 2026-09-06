import { Router } from 'express';
import multer from 'multer';
import { bmoni, BmoniApiError } from '../config/bmoni.js';

const router = Router();
const upload = multer({ storage: multer.memoryStorage() });

/// GET /api/v1/users/:userId/kyc/options — KYC field options
router.get('/:userId/kyc/options', async (req, res) => {
  try {
    const options = await bmoni.get(`/v1/users/${req.params.userId}/kyc/options`);
    res.json(options);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/occupations — occupation autocomplete
router.get('/:userId/kyc/occupations', async (req, res) => {
  try {
    const search = req.query.search || '';
    const occupations = await bmoni.get(
      `/v1/users/${req.params.userId}/kyc/occupations?search=${encodeURIComponent(search as string)}`,
    );
    res.json(occupations);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/bvn-lookup/:bvn — BVN lookup (fetch only)
router.get('/:userId/kyc/bvn-lookup/:bvn', async (req, res) => {
  try {
    const result = await bmoni.get(
      `/v1/users/${req.params.userId}/kyc/bvn-lookup/${req.params.bvn}`,
    );
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/kyc/documents/identification — upload ID document
router.post(
  '/:userId/kyc/documents/identification',
  upload.single('file'),
  async (req, res) => {
    try {
      const formData = new FormData();
      if (req.file) {
        const blob = new Blob([req.file.buffer], { type: req.file.mimetype });
        formData.append('file', blob, req.file.originalname);
      }
      if (req.body.type) formData.append('type', req.body.type);
      if (req.body.documentNumber) formData.append('documentNumber', req.body.documentNumber);
      if (req.body.issuingCountryCode) formData.append('issuingCountryCode', req.body.issuingCountryCode);
      if (req.body.expirationDate) formData.append('expirationDate', req.body.expirationDate);

      const result = await bmoni.upload(
        `/v1/users/${req.params.userId}/kyc/documents/identification`,
        formData,
      );
      res.json(result);
    } catch (err) {
      handleError(res, err);
    }
  },
);

/// POST /api/v1/users/:userId/kyc/documents/proof-of-address — upload proof of address
router.post(
  '/:userId/kyc/documents/proof-of-address',
  upload.single('file'),
  async (req, res) => {
    try {
      const formData = new FormData();
      if (req.file) {
        const blob = new Blob([req.file.buffer], { type: req.file.mimetype });
        formData.append('file', blob, req.file.originalname);
      }
      if (req.body.type) formData.append('type', req.body.type);

      const result = await bmoni.upload(
        `/v1/users/${req.params.userId}/kyc/documents/proof-of-address`,
        formData,
      );
      res.json(result);
    } catch (err) {
      handleError(res, err);
    }
  },
);

/// POST /api/v1/users/:userId/kyc/documents/biometric — upload selfie
router.post(
  '/:userId/kyc/documents/biometric',
  upload.single('file'),
  async (req, res) => {
    try {
      const formData = new FormData();
      if (req.file) {
        const blob = new Blob([req.file.buffer], { type: req.file.mimetype });
        formData.append('file', blob, req.file.originalname);
      }

      const result = await bmoni.upload(
        `/v1/users/${req.params.userId}/kyc/documents/biometric`,
        formData,
      );
      res.json(result);
    } catch (err) {
      handleError(res, err);
    }
  },
);

/// PATCH /api/v1/users/:userId/kyc — Submit KYC profile (personal + address + employment + compliance)
router.patch('/:userId/kyc', async (req, res) => {
  try {
    const result = await bmoni.patch(`/v1/users/${req.params.userId}/kyc`, req.body);
    res.json(result);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/readiness — check if KYC is ready for activation
router.get('/:userId/kyc/readiness', async (req, res) => {
  try {
    const readiness = await bmoni.get(`/v1/users/${req.params.userId}/kyc/readiness`);
    res.json(readiness);
  } catch (err) {
    handleError(res, err);
  }
});

/// GET /api/v1/users/:userId/kyc/usd-readiness — USD-specific readiness check
router.get('/:userId/kyc/usd-readiness', async (req, res) => {
  try {
    const readiness = await bmoni.get(`/v1/users/${req.params.userId}/kyc/usd-readiness`);
    res.json(readiness);
  } catch (err) {
    handleError(res, err);
  }
});

/// POST /api/v1/users/:userId/kyc/activate — Start identity verification
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

/// GET /api/v1/users/:userId/onboarding/status — Check onboarding status
router.get('/:userId/onboarding/status', async (req, res) => {
  try {
    const status = await bmoni.get(`/v1/users/${req.params.userId}/onboarding/status`);
    res.json(status);
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
