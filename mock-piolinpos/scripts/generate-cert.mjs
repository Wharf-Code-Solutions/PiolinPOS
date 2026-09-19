import { execFileSync } from "node:child_process";
import { networkInterfaces } from "node:os";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

/** Detecta la primera IPv4 de LAN no interna (ignora loopback/APIPA). */
function detectarIpLan() {
  const ifaces = networkInterfaces();
  for (const nombre of Object.keys(ifaces)) {
    for (const iface of ifaces[nombre] ?? []) {
      if (iface.family === "IPv4" && !iface.internal && !iface.address.startsWith("169.254")) {
        return iface.address;
      }
    }
  }
  return null;
}

const ipLan = detectarIpLan();
const certsDir = path.join(process.cwd(), "certs");
mkdirSync(certsDir, { recursive: true });

const altNames = ["DNS.1 = localhost", "IP.1 = 127.0.0.1"];
if (ipLan) altNames.push(`IP.2 = ${ipLan}`);

const config = `[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = piolinpos-dev

[v3_req]
keyUsage = keyEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
${altNames.join("\n")}
`;

const configPath = path.join(tmpdir(), `piolinpos-san-${Date.now()}.cnf`);
writeFileSync(configPath, config);

const keyPath = path.join(certsDir, "dev-key.pem");
const certPath = path.join(certsDir, "dev-cert.pem");

try {
  execFileSync(
    "openssl",
    [
      "req", "-x509", "-newkey", "rsa:2048", "-nodes",
      "-keyout", keyPath,
      "-out", certPath,
      "-days", "825",
      "-config", configPath,
    ],
    { stdio: "inherit" },
  );
} finally {
  rmSync(configPath, { force: true });
}

console.log(`\nCertificado generado en certs/ para: ${altNames.map((l) => l.split(" = ")[1]).join(", ")}`);
if (!ipLan) {
  console.warn("No se detectó una IP de LAN — el celular no podrá conectarse hasta regenerar el certificado en una red con Wi-Fi activo.");
} else {
  console.log(`Desde el celular (misma red Wi-Fi): https://${ipLan}:5173/#/pedidos`);
}
