import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  root: '.',
  publicDir: 'assets',
  server: {
    port: 3000,
    host: true,
    open: true,
    proxy: {
      '/lobby': 'http://localhost:8000',
      '/socket.io': { target: 'http://localhost:8000', ws: true },
      '/health': 'http://localhost:8000',
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    emptyOutDir: true,
  },
});
