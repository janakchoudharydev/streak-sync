import dotenv from 'dotenv';
dotenv.config();

import { app } from './app';

const PORT = process.env.PORT || 3000;

app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`[Streak Sync Backend] running on port ${PORT}`);
  console.log(`[Streak Sync Backend] Local Health check: http://localhost:${PORT}/api/health`);
  console.log(`[Streak Sync Backend] LAN Health check: http://0.0.0.0:${PORT}/api/health`);
});
