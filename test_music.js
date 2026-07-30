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
  __nativeGetRandomValues: (byteLength) => crypto.randomBytes(byteLength),
  __nativeRandomUUID: () => crypto.randomUUID(),
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

async function runMusicTest() {
  loadPolyfills();
  load('runtime.bundle.js');

  const testScript = `
    (async () => {
      try {
        console.log("=== Testing YouTube Music Search in JSC ===");
        const yt = await Innertube.create({ cache: new UniversalCache(false) });
        
        const query = "Daft Punk Get Lucky";
        console.log("Searching YouTube Music for:", JSON.stringify(query));
        const musicResults = await yt.music.search(query, { type: 'song' });
        
        const songs = musicResults.songs?.contents || musicResults.results || [];
        console.log("Returned", songs.length, "songs!");
        
        for (let i = 0; i < Math.min(5, songs.length); i++) {
          const s = songs[i];
          console.log("[" + (i+1) + "] Title:", s.title || s.name || s.title?.text);
          console.log("    Artist:", s.artists ? s.artists.map(a=>a.name).join(", ") : (s.author?.name || "N/A"));
          console.log("    Album:", s.album?.name || "N/A");
          console.log("    Video ID:", s.id);
          console.log("    Duration:", s.duration?.text || s.duration || "N/A");
        }

        if (songs[0] && songs[0].id) {
          const songId = songs[0].id;
          console.log("\\nFetching stream URL for music song ID:", songId);
          const info = await yt.getInfo(songId, { client: 'ANDROID_VR' });
          const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
          const m4aAudioFormats = adaptiveFormats.filter(f => f.has_audio && !f.has_video && (f.mime_type?.includes('mp4') || f.mime_type?.includes('m4a')));
          m4aAudioFormats.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
          const audioFormat = m4aAudioFormats[0] || adaptiveFormats.find(f => f.has_audio && !f.has_video);
          console.log("Audio Stream ITAG:", audioFormat?.itag);
          console.log("Audio Stream Bitrate:", audioFormat?.bitrate);
          console.log("Audio Stream MimeType:", audioFormat?.mime_type);
          console.log("Audio Stream URL:", audioFormat?.url ? audioFormat.url.substring(0, 100) + "..." : "N/A");
        }

      } catch (err) {
        console.error("Music Test Error:", err.stack || err.message || err);
      }
    })()
  `;

  const promise = vm.runInContext(testScript, context, { filename: 'music_test.js' });
  await promise;
}

runMusicTest();
