import { config } from 'dotenv';
import { resolve } from 'node:path';
import { createServer } from 'node:http';
import { Queue } from 'bullmq';
import { Redis } from 'ioredis';
import { z } from 'zod';
import { queues } from '@askadia/contracts';
config({ path: resolve(__dirname, '../../../.env'), quiet: true });
const env = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  WORKER_HEALTH_PORT: z.coerce.number().int().min(1).max(65535).default(4001),
  REDIS_URL: z.union([z.url(), z.literal('')]).optional(),
}).parse(process.env);
if (env.NODE_ENV === 'production') throw new Error('Production disabled: business job handlers are not implemented.');
const connection = env.REDIS_URL ? new Redis(env.REDIS_URL, { maxRetriesPerRequest: null, lazyConnect: true }) : null;
let ready = false;
connection?.on('error', () => { ready = false; });
connection?.on('ready', () => { ready = true; });
connection?.on('close', () => { ready = false; });
const registry = connection ? queues.map(name => new Queue(name, { connection })) : [];
// No business jobs are consumed until authorization and provider reconciliation exist.
const server = createServer((req, res) => {
  if (req.url !== '/health') { res.writeHead(404); res.end(); return; }
  res.writeHead(connection && !ready ? 503 : 200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ status: connection ? (ready ? 'ready' : 'unavailable') : 'idle', service: 'askadia-worker', queues, processing: false, reason: 'Business handlers pending implementation' }));
}).listen(env.WORKER_HEALTH_PORT, '127.0.0.1', () => console.log('Worker health available; external processing disabled.'));
async function shutdown() {
  await Promise.all(registry.map(queue => queue.close()));
  if (connection) connection.disconnect();
  server.close();
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
