import dotenv from 'dotenv';
dotenv.config();

import { app } from './app';
import { db } from './db';

const PORT = process.env.PORT || 3000;

async function bootstrap() {
  try {
    await db.init();
    console.log(`[Streak Sync Backend] database initialized (${db.type})`);
  } catch (err) {
    console.error('[Streak Sync Backend] database init error:', err);
  }

  app.listen(Number(PORT), '0.0.0.0', () => {
    console.log(`[Streak Sync Backend] running on port ${PORT}`);
    console.log(`[Streak Sync Backend] Local Health check: http://localhost:${PORT}/api/health`);
    console.log(`[Streak Sync Backend] LAN Health check: http://0.0.0.0:${PORT}/api/health`);
  });
}

bootstrap();
