import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// Relative base so the build works on GitHub Pages under /<repo-name>/.
export default defineConfig({
  plugins: [react()],
  base: './',
})
