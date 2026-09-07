import { defineConfig, createLogger } from 'vite';
import react from '@vitejs/plugin-react';

const logger = createLogger();
const originalError = logger.error.bind(logger);
logger.error = (msg, options) => {
  const code = options?.error?.code;
  if (code === 'ECONNABORTED' || code === 'ECONNRESET') return;
  if (typeof msg === 'string' && (msg.includes('ECONNABORTED') || msg.includes('ECONNRESET'))) return;
  originalError(msg, options);
};

export default defineConfig({
  customLogger: logger,
  plugins: [react()],
  root: '.',
  publicDir: 'assets',
  server: {
    port: 3000,
    host: true,
    open: true,
    proxy: {
      '/lobby': 'http://localhost:8000',
      '/socket.io': {
        target: 'http://localhost:8000',
        ws: true,
        configure: (proxy) => {
          proxy.on('error', (err) => {
            if (err.code === 'ECONNRESET' || err.code === 'ECONNABORTED') return;
            console.error('Socket proxy error:', err.message);
          });
        },
      },
      '/health': 'http://localhost:8000',
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    emptyOutDir: true,
  },
});
