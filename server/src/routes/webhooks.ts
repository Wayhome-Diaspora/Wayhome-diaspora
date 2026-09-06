import { Router, raw } from 'express';
import crypto from 'node:crypto';
import { config } from '../config/env.js';

const router = Router();

// In-memory event log (replace with database in production)
interface WebhookEvent {
  id: string;
  eventType: string;
  payload: Record<string, unknown>;
  timestamp: string;
  receivedAt: Date;
}

const eventLog: WebhookEvent[] = [];
const processedIds = new Set<string>();

/// POST /api/v1/webhooks/bmoni — Receive BMONI webhook deliveries
/// Uses raw body for HMAC signature verification
router.post('/bmoni', raw({ type: 'application/json' }), (req, res) => {
  const rawBody = req.body as Buffer;

  // Verify HMAC signature
  const signature = req.get('X-Webhook-Signature') ?? '';
  const webhookSecret = config.bmoni.webhookSecret;

  if (webhookSecret) {
    const expected = crypto
      .createHmac('sha256', webhookSecret)
      .update(rawBody)
      .digest('hex');

    const ok =
      signature.length === expected.length &&
      crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));

    if (!ok) {
      console.warn('⚠️  Invalid webhook signature');
      return res.status(401).json({ error: 'Invalid webhook signature' });
    }
  }

  // Parse and process
  try {
    const event = JSON.parse(rawBody.toString('utf8'));

    // Deduplicate
    if (event.id && processedIds.has(event.id)) {
      return res.status(200).json({ received: true, duplicate: true });
    }

    // Store event
    const webhookEvent: WebhookEvent = {
      id: event.id,
      eventType: event.eventType,
      payload: event.payload,
      timestamp: event.timestamp,
      receivedAt: new Date(),
    };
    eventLog.unshift(webhookEvent);
    if (event.id) processedIds.add(event.id);

    // Log for visibility
    console.log(`📨 Webhook: ${event.eventType} — ${JSON.stringify(event.payload).slice(0, 200)}`);

    // Acknowledge immediately (per docs: acknowledge first, process after)
    res.status(200).json({ received: true });

    // Process event asynchronously
    processEvent(event);
  } catch (err) {
    console.error('Webhook processing error:', err);
    // Return 5xx to trigger retry
    res.status(500).json({ error: 'Processing error' });
  }
});

/// GET /api/v1/webhooks/events — List received webhook events (for debugging)
router.get('/events', (_req, res) => {
  res.json({ events: eventLog.slice(0, 100), total: eventLog.length });
});

/// Process a webhook event (stub — extend for real handling)
function processEvent(event: Record<string, unknown>) {
  const eventType = event.eventType as string;
  const payload = event.payload as Record<string, unknown>;

  // Log status updates for transfer tracking
  if (eventType === 'employee.withdrawal.completed') {
    console.log(`✅ Withdrawal completed for user ${payload.userId}`);
  } else if (eventType === 'employee.withdrawal.failed') {
    console.log(`❌ Withdrawal failed for user ${payload.userId}`);
  } else if (eventType === 'employee.deposit.completed') {
    console.log(`💰 Deposit completed for user ${payload.userId}`);
  } else if (eventType === 'onboarding.completed') {
    console.log(`🎉 Onboarding completed for user ${payload.userId}`);
  }
}

export default router;
