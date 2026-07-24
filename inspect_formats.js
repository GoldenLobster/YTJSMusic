import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const sandbox = {
  __nativeLog: (level, msg) => {
    const prefix = `[JSC-${level}]`;
    if (level === 'ERROR') {
      console.error(prefix, msg);
    } else if (level === 'WARN') {
      console.warn(prefix, msg);
    } else {
      console.log(prefix, msg);
    }
  },
  __nativeFetch: async (params) => {
    try {
      const options = {
        method: params.method,
        headers: params.headers
      };
      if (params.body) {
        if (typeof params.body === 'string') {
          options.body = params.body;
        } else if (Array.isArray(params.body)) {
          options.body = Uint8Array.from(params.body);
        }
      }
      const res = await fetch(params.url, options);
      const buffer = await res.arrayBuffer();
      const resHeaders = [];
      res.headers.forEach((v, k) => resHeaders.push([k, v]));
      return {
        status: res.status,
        statusText: res.statusText,
        headers: resHeaders,
        body: Array.from(new Uint8Array(buffer))
      };
    } catch (err) {
      console.error('[NATIVE FETCH ERROR]', err);
      throw err;
    }
  },
  __nativeGetRandomValues: (byteLength) => {
    return Array.from(crypto.randomBytes(byteLength));
  },
  __nativeRandomUUID: () => {
    return crypto.randomUUID();
  },
  __nativeSubtleDigest: async (algorithm, bytes) => {
    const hash = crypto.createHash(algorithm.toLowerCase());
    hash.update(Buffer.from(bytes));
    return Array.from(hash.digest());
  },
  __nativeSubtleSign: async (algorithm, key, bytes) => {
    const hmac = crypto.createHmac(algorithm.toLowerCase(), Buffer.from(key));
    hmac.update(Buffer.from(bytes));
    return Array.from(hmac.digest());
  },
  __nativeSetTimeout: (cb, ms) => setTimeout(cb, ms),
  __nativeClearTimeout: (id) => clearTimeout(id),
  __nativeSetInterval: (cb, ms) => setInterval(cb, ms),
  __nativeClearInterval: (id) => clearInterval(id),
  __nativePerformanceNow: () => performance.now()
};

const context = vm.createContext(sandbox);

function load(filePath) {
  const absolutePath = path.resolve(filePath);
  if (!fs.existsSync(absolutePath)) return;
  const code = fs.readFileSync(absolutePath, 'utf8');
  return vm.runInContext(code, context, { filename: filePath });
}

function loadPolyfills() {
  const polyfillsDir = path.resolve('polyfills');
  if (!fs.existsSync(polyfillsDir)) return;
  const files = fs.readdirSync(polyfillsDir).filter(f => f.endsWith('.js')).sort();
  for (const file of files) {
    load(path.join('polyfills', file));
  }
}

async function runInspection() {
  loadPolyfills();
  load('runtime.bundle.js');

  const testScript = `
    (async () => {
      try {
        console.log("=== Testing getInfo with TV_EMBEDDED and IOS client ===");
        const yt = await Innertube.create({ cache: new UniversalCache(false) });
        
        const videoId = "nAchMctX4YA";

        console.log("\\n--- Testing client: TV_EMBEDDED ---");
        try {
          const infoTv = await yt.getInfo(videoId, { client: 'TV_EMBEDDED' });
          const formatsTv = infoTv.streaming_data?.adaptive_formats || [];
          console.log("TV_EMBEDDED formats count:", formatsTv.length);
          if (formatsTv[0]) {
            console.log("TV_EMBEDDED format 0 keys:", Object.keys(formatsTv[0]));
            console.log("TV_EMBEDDED format 0 url:", formatsTv[0].url ? formatsTv[0].url.substring(0, 80) + '...' : 'undefined');
            console.log("TV_EMBEDDED format 0 signature_cipher:", formatsTv[0].signature_cipher);
            console.log("TV_EMBEDDED format 0 cipher:", formatsTv[0].cipher);
          }
        } catch (e) {
          console.error("TV_EMBEDDED error:", e.message);
        }

        console.log("\\n--- Testing client: IOS ---");
        try {
          const infoIos = await yt.getInfo(videoId, { client: 'IOS' });
          const formatsIos = infoIos.streaming_data?.adaptive_formats || [];
          console.log("IOS formats count:", formatsIos.length);
          if (formatsIos[0]) {
            console.log("IOS format 0 keys:", Object.keys(formatsIos[0]));
            console.log("IOS format 0 url:", formatsIos[0].url ? formatsIos[0].url.substring(0, 80) + '...' : 'undefined');
            console.log("IOS format 0 signature_cipher:", formatsIos[0].signature_cipher);
            console.log("IOS format 0 cipher:", formatsIos[0].cipher);
          }
        } catch (e) {
          console.error("IOS error:", e.message);
        }

      } catch (err) {
        console.error("Inspection error:", err.stack || err.message);
      }
    })()
  `;

  const promise = vm.runInContext(testScript, context, { filename: 'inspect_test.js' });
  await promise;
}

runInspection();
