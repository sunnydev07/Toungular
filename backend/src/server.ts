import { createApp } from './app.js';

const port = Number.parseInt(process.env.PORT ?? '3000', 10);
const app = createApp();

app.listen(port, () => {
  console.info(`Toungular API listening on port ${port}`);
});
