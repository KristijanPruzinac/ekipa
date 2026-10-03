/** Hosted previews must never connect to the production database. */
export function assertProductionEnvironment(environment: NodeJS.ProcessEnv) {
  if (environment.VERCEL === '1' && environment.VERCEL_ENV !== 'production') {
    throw new Error('Database access is disabled outside the production deployment.');
  }
}
