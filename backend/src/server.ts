import { createApp } from './app.js';
import { loadEnv } from './config/env.js';

const env = loadEnv();
const app = createApp(env);

app.listen(env.port, () => {
  console.info(`Toungular API listening on port ${env.port}`);
});
