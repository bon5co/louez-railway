// Registers Louez's owner on the loopback listener; the app closes public registration itself once the first account exists.
// Idempotent: a second boot finds registration closed, signs in as the owner and reports whether the password still matches.
// Requests carry the public Host and Origin because better-auth checks the origin of a sign-up against AUTH_URL.
const http = require("http");

const port = Number(process.argv[2]);
const origin = new URL(process.env.AUTH_URL).origin;
const host = new URL(origin).host;
const email = process.env.ADMIN_EMAIL.trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD;
const name = process.env.ADMIN_NAME || "Owner";

function call(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? null : JSON.stringify(body);
    const headers = { Host: host, Origin: origin };
    if (data) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = Buffer.byteLength(data);
    }
    const req = http.request({ host: "127.0.0.1", port, method, path, headers }, (res) => {
      let text = "";
      res.on("data", (c) => (text += c));
      res.on("end", () => resolve({ status: res.statusCode, text }));
    });
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitHealthy() {
  for (let i = 0; i < 150; i++) {
    try {
      const r = await call("GET", "/api/health");
      if (r.status === 200) return;
    } catch (e) {}
    await sleep(2000);
  }
  throw new Error("server did not become healthy on the loopback port within 300s");
}

(async () => {
  await waitHealthy();
  const up = await call("POST", "/api/auth/sign-up/email", { name, email, password });
  if (up.status === 200) {
    console.log("[bootstrap] owner registered; public registration is now closed");
    return;
  }
  if (up.status === 403 && /REGISTRATION_CLOSED/.test(up.text)) {
    const inn = await call("POST", "/api/auth/sign-in/email", { email, password });
    if (inn.status === 200) console.log("[bootstrap] owner already registered; ADMIN_PASSWORD still signs in");
    else console.log("[bootstrap] owner already registered; ADMIN_PASSWORD no longer matches (changed in the app), leaving it");
    return;
  }
  throw new Error(`sign-up answered ${up.status}: ${up.text.slice(0, 300)}`);
})().catch((e) => {
  console.error(`[bootstrap] ${e.message}`);
  process.exit(1);
});
