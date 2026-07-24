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

async function runDemo() {
  console.log("===============================================================");
  console.log("  YouTube.js in Bare JavaScriptCore - Full End-to-End Test");
  console.log("===============================================================\n");

  loadPolyfills();
  load('runtime.bundle.js');

  const testScript = `
    (async () => {
      try {
        console.log("1. Initializing Innertube client in JavaScriptCore...");
        const yt = await Innertube.create({
          cache: new UniversalCache(false)
        });
        console.log("   [OK] Innertube initialized successfully!\\n");

        const searchQuery = "Swift in 100 seconds";
        console.log("2. Searching YouTube for:", JSON.stringify(searchQuery) + "...");
        const searchResults = await yt.search(searchQuery);

        const videoList = searchResults.videos || [];
        console.log("   [OK] Search completed! Returned", videoList.length, "video results.\\n");

        console.log("   Top 3 Search Results:");
        for (let i = 0; i < Math.min(3, videoList.length); i++) {
          const v = videoList[i];
          console.log("   [" + (i+1) + "] ID: " + v.id + " | Title: " + (v.title?.text || "N/A") + " (" + (v.duration?.text || "N/A") + ")");
        }
        console.log("");

        const selectedVideo = videoList[0];
        if (!selectedVideo || !selectedVideo.id) {
          throw new Error("No valid video found in search results");
        }

        console.log("3. Fetching full video details for video ID:", selectedVideo.id, "using IOS client...");
        const info = await yt.getInfo(selectedVideo.id, { client: 'IOS' });
        console.log("   [OK] Title:", info.basic_info.title);
        console.log("   [OK] Channel:", info.basic_info.author);
        console.log("   [OK] Duration:", info.basic_info.duration, "seconds");
        console.log("   [OK] View Count:", info.basic_info.view_count);
        console.log("");

        console.log("4. Extracting direct playable streaming URLs...");
        const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
        
        // Find best audio format
        const audioFormat = adaptiveFormats.find(f => f.has_audio && !f.has_video);
        if (audioFormat) {
          console.log("   [OK] Best Audio Format:");
          console.log("     • ITAG:", audioFormat.itag);
          console.log("     • MimeType:", audioFormat.mime_type);
          console.log("     • Bitrate:", audioFormat.bitrate, "bps");
          console.log("     • Direct Audio Stream URL:");
          console.log("       " + audioFormat.url);
          console.log("");
        }

        // Find best video format
        const videoFormat = adaptiveFormats.find(f => f.has_video);
        if (videoFormat) {
          console.log("   [OK] Best Video Format:");
          console.log("     • ITAG:", videoFormat.itag);
          console.log("     • Quality:", videoFormat.quality_label);
          console.log("     • MimeType:", videoFormat.mime_type);
          console.log("     • Direct Video Stream URL:");
          console.log("       " + videoFormat.url);
          console.log("");
        }

        console.log("===============================================================");
        console.log("  SUCCESS! YouTube.js search + stream extraction completed.");
        console.log("===============================================================");

      } catch (err) {
        console.error("  [FAILED] TEST ERROR:", err.stack || err.message || err);
      }
    })()
  `;

  const promise = vm.runInContext(testScript, context, { filename: 'demo_test.js' });
  await promise;
}

runDemo();
