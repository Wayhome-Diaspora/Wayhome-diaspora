import express from 'express';
import cors from 'cors';
import { config } from './config/env.js';
import usersRouter from './routes/users.js';
import kycRouter from './routes/kyc.js';
import transfersRouter from './routes/transfers.js';
import withdrawalsRouter from './routes/withdrawals.js';
import webhooksRouter from './routes/webhooks.js';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'waya-server' });
});

// Routes
app.use('/api/v1/users', usersRouter);
app.use('/api/v1/users', kycRouter);
app.use('/api/v1/users', transfersRouter);
app.use('/api/v1/users', withdrawalsRouter);
app.use('/api/v1/webhooks', webhooksRouter);

// Error handler
app.use(
  (
    err: Error,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  },
);

// Start server
app.listen(config.port, '0.0.0.0', () => {
  console.log(`🚀 Waya server running on http://0.0.0.0:${config.port}`);
  console.log(`   BMONI base URL: ${config.bmoni.baseUrl}`);
});
