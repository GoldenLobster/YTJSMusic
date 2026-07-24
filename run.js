import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const sandbox = {
  __nativeLog: (level, msg) => {
    const prefix = `[JSC ${level}]`;
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
  if (!fs.existsSync(absolutePath)) {
    console.warn(`[WARN] File not found: ${filePath}`);
    return;
  }
  const code = fs.readFileSync(absolutePath, 'utf8');
  console.log(`[LOAD] Loading: ${filePath}`);
  return vm.runInContext(code, context, { filename: filePath });
}

function loadPolyfills() {
  const polyfillsDir = path.resolve('polyfills');
  if (!fs.existsSync(polyfillsDir)) return;
  
  const files = fs.readdirSync(polyfillsDir)
    .filter(f => f.endsWith('.js'))
    .sort();

  for (const file of files) {
    load(path.join('polyfills', file));
  }
}

console.log('--- Phase 1: Running in Bare JavaScriptCore Simulation ---');

async function main() {
  try {
    loadPolyfills();
    load('runtime.bundle.js');
    
    console.log('[SUCCESS] runtime.bundle.js loaded without error!');

    const testScript = `
      (async () => {
        try {
          console.log("[TEST] Creating Innertube instance...");
          const yt = await Innertube.create({
            cache: new UniversalCache(false)
          });
          console.log("[TEST] Innertube initialized successfully!");
          
          console.log("[TEST] Searching YouTube for 'Swift iOS'...");
          const searchResults = await yt.search("Swift iOS");
          console.log("[TEST] Search results count:", searchResults.videos?.length || 0);
          console.log("[TEST] First video title:", searchResults.videos[0]?.title?.text);

          const targetVideoId = searchResults.videos[0]?.id || "nAchMctX4YA";
          console.log("[TEST] Fetching getInfo for video ID:", targetVideoId);
          const info = await yt.getInfo(targetVideoId);
          console.log("[TEST] Video Title:", info.basic_info?.title);
          console.log("[TEST] Video Author:", info.basic_info?.author);

          const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
          console.log("[TEST] Total adaptive formats:", adaptiveFormats.length);

        } catch (err) {
          console.error("[TEST FAILED]", err.stack || err.message || String(err));
        }
      })()
    `;

    const promise = vm.runInContext(testScript, context, { filename: 'test_execution.js' });
    await promise;

  } catch (err) {
    console.error('\n[RUNTIME ERROR DETECTED]');
    console.error(err.stack || err.message || err);
  }
}

main();
