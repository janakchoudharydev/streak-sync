import express, { Request, Response } from 'express';
import cors from 'cors';
import { AuthService, authMiddleware, AuthenticatedRequest } from './services/auth';
import { SyncEngine } from './services/syncEngine';
import { db } from './db';

export const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Root Status Route (for browser checks)
app.get('/', (req: Request, res: Response) => {
  res.json({
    service: 'Streak Cloud Sync Backend',
    status: 'online',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      register: 'POST /api/auth/register',
      login: 'POST /api/auth/login',
      sync: 'POST /api/sync',
    },
  });
});

// Health Check
app.get('/api/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'streak-sync-backend',
    database: db.type,
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
