import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { db, UserRecord } from '../db';
import { Request, Response, NextFunction } from 'express';

const JWT_SECRET = process.env.JWT_SECRET || 'streak_super_secret_jwt_key_2026';
const SALT_ROUNDS = 10;

export interface TokenPayload {
  userId: string;
  email: string;
}

export interface AuthenticatedRequest extends Request {
  user?: TokenPayload;
}

export class AuthService {
  static async register(email: string, password: string): Promise<{ token: string; user: { id: string; email: string } }> {
    if (!email || !email.includes('@')) {
      throw new Error('Valid email address is required');
    }
    if (!password || password.length < 6) {
      throw new Error('Password must be at least 6 characters long');
    }

    const existing = await db.findUserByEmail(email);
    if (existing) {
      throw new Error('An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);
    const user = await db.createUser(email, passwordHash);

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return {
      token,
      user: { id: user.id, email: user.email },
    };
  }

  static async login(email: string, password: string): Promise<{ token: string; user: { id: string; email: string } }> {
    if (!email || !password) {
      throw new Error('Email and password are required');
    }

    const user = await db.findUserByEmail(email);
    if (!user) {
      throw new Error('Invalid email or password');
    }

    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      throw new Error('Invalid email or password');
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email },
      JWT_SECRET,
      { expiresIn: '30d' }
    );

    return {
      token,
      user: { id: user.id, email: user.email },
    };
  }

  static verifyToken(token: string): TokenPayload {
    try {
      return jwt.verify(token, JWT_SECRET) as TokenPayload;
    } catch {
      throw new Error('Invalid or expired authentication token');
    }
  }
}

export function authMiddleware(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or malformed Authorization header' });
    return;
  }

  const token = authHeader.substring(7);
  try {
    const payload = AuthService.verifyToken(token);
    req.user = payload;
    next();
  } catch (err: any) {
    res.status(401).json({ error: err.message || 'Unauthorized' });
  }
}
