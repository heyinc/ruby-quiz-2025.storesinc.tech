import { defineConfig } from 'vite';

export default defineConfig({
  build: {
    assetsDir: 'assets',
    rollupOptions: {
      input: {
        main: './index.html',
      },
    },
  },
  publicDir: 'public',
  assetsInclude: ['**/*.sixel'],
});
