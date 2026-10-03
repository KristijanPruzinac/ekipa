import { existsSync } from 'node:fs';

if (existsSync('.env')) process.loadEnvFile('.env');
const number = (key: string, fallback: number, min = 0) => {
  const value = process.env[key] ? Number(process.env[key]) : fallback;
  if (!Number.isFinite(value) || value < min) throw new Error(`Invalid ${key}`);
  return value;
};
export const config = {
  host: process.env.HOST || '127.0.0.1',
  port: number('PORT', 3000, 1),
  databasePath: process.env.WAGZ_DATABASE_PATH || 'data/wagz.sqlite',
  databaseUrl: process.env.DATABASE_URL,
  hosted: process.env.VERCEL === '1',
  adminKey: process.env.WAGZ_ADMIN_KEY || '',
  autoPublish: process.env.WAGZ_AUTO_PUBLISH !== 'false',
  fetchOnStart: process.env.WAGZ_FETCH_ON_START !== 'false',
  fetchIntervalMinutes: number('WAGZ_FETCH_INTERVAL_MINUTES', 360, 5),
  ai: {
    apiKey: process.env.OPENROUTER_API_KEY || '',
    model: process.env.OPENROUTER_MODEL || 'google/gemini-2.5-flash-lite',
    monthlyBudgetUsd: number('WAGZ_AI_MONTHLY_BUDGET_USD', 1),
    searchEnabled: process.env.WAGZ_AI_SEARCH_ENABLED !== 'false',
  },
};
export type Config = Omit<typeof config, 'databaseUrl' | 'hosted'> & {
  databaseUrl?: string;
  hosted?: boolean;
};
