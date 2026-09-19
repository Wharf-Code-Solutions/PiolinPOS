import { readFileSync } from 'node:fs'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: true,
    // Certificado autofirmado (certs/) para servir por HTTPS: el micrófono
    // del celular (getUserMedia) solo funciona en localhost o HTTPS. El
    // navegador del celular mostrará "sitio no seguro" una vez — hay que
    // aceptar el aviso, y ya. Regenerar con certs/README si cambia la IP de LAN.
    https: {
      key: readFileSync('certs/dev-key.pem'),
      cert: readFileSync('certs/dev-cert.pem'),
    },
    // El backend de voz corre aparte (server/); el navegador solo habla con
    // Vite, que reenvía /voz por detrás. Así el celular nunca necesita saber
    // la IP ni el puerto del backend, y evitamos CORS por completo.
    proxy: {
      "/voz": "http://localhost:4000",
    },
  },
})
