import type { NextConfig } from 'next';
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';
import { resolve } from 'node:path';
const rootEnv=resolve(process.cwd(),'../../.env');
if(existsSync(rootEnv)) loadEnvFile(rootEnv);
const config:NextConfig={transpilePackages:['@askadia/ui'],poweredByHeader:false};
export default config;
