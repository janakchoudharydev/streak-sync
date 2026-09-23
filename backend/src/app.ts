import express, { Request, Response } from 'express';
import cors from 'cors';
import { AuthService, authMiddleware, AuthenticatedRequest } from './services/auth';
import { SyncEngine } from './services/syncEngine';

export const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health Check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'streak-sync-backend',
  });
});

// Auth Routes
app.post('/api/auth/register', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    const result = await AuthService.register(email, password);
    res.status(201).json(result);
  } catch (err: any) {
    res.status(400).json({ error: err.message || 'Registration failed' });
  }
});

app.post('/api/auth/login', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    const result = await AuthService.login(email, password);
    res.json(result);
  } catch (err: any) {
    res.status(401).json({ error: err.message || 'Invalid credentials' });
  }
});

// Protected Sync Endpoint
app.post('/api/sync', authMiddleware, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const syncRequest = req.body || {};
    const result = await SyncEngine.processSync(userId, syncRequest);
    res.json(result);
  } catch (err: any) {
    res.status(500).json({ error: err.message || 'Sync processing failed' });
  }
});
