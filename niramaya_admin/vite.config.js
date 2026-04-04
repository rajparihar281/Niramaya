import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Proxy API calls to the Go backend so the admin panel doesn't need CORS
    proxy: {
      '/v1': {
        target: 'http://192.168.1.35:10000',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path.replace(/^\/v1/, '/v1'),
      },
    },
  },
})
