import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execSync } from 'node:child_process';

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

function testFFmpegChunk(streamUrl, streamType, title, outFile) {
  console.log(`\n===============================================================`);
  console.log(`  Downloading Media Chunk & Demuxing with FFmpeg`);
  console.log(`  Target: "${title}"`);
  console.log(`===============================================================`);

  const userAgent = "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X; en_US)";
  const tmpFile = `/tmp/${outFile}`;
  
  // Download 1.5MB range chunk using curl
  const curlCmd = `curl -s -L -r 0-1500000 -A "${userAgent}" -H "Origin: https://www.youtube.com" "${streamUrl}" -o "${tmpFile}"`;
  console.log(`1. Downloading 1.5MB stream chunk via curl to ${tmpFile}...`);
  execSync(curlCmd);

  const stats = fs.statSync(tmpFile);
  console.log(`   ✓ Downloaded ${stats.size} bytes of stream data.\n`);

  // Probe chunk with ffmpeg
  const ffmpegCmd = `ffmpeg -y -i "${tmpFile}" -t 3 -f null - 2>&1`;
  console.log(`2. Demuxing and decoding ${streamType} container with FFmpeg...`);
  try {
    const output = execSync(ffmpegCmd).toString();
    const lines = output.split('\n').filter(line => 
      line.includes('Input #0') || 
      line.includes('Duration:') || 
      line.includes('Stream #0') || 
      line.includes('video:') || 
      line.includes('audio:') ||
      line.includes('frame=') ||
      line.includes('size=')
    ).join('\n');
    
    console.log(lines);
    console.log(`\n  ✅ SUCCESS! ${streamType} stream container decoded & verified cleanly!`);
  } catch (err) {
    const output = err.output ? err.output.toString() : err.message;
    console.log(output);
  }
}

async function runPlaybackTest() {
  console.log("===============================================================");
  console.log("  YouTube.js JSC Stream Extraction + FFmpeg Playback Test");
  console.log("===============================================================\n");

  loadPolyfills();
  load('runtime.bundle.js');

  const testScript = `
    (async () => {
      const yt = await Innertube.create({ cache: new UniversalCache(false) });
      const searchQuery = "Swift in 100 seconds";
      console.log("Searching YouTube for:", JSON.stringify(searchQuery));
      const searchResults = await yt.search(searchQuery);
      
      const video = searchResults.videos[0];
      console.log("Selected Video:", video.title.text, "| ID:", video.id);
      
      const info = await yt.getInfo(video.id, { client: 'IOS' });
      const adaptiveFormats = info.streaming_data?.adaptive_formats || [];
      
      // WebM Opus Audio Format
      const audioFormat = adaptiveFormats.find(f => f.has_audio && !f.has_video && f.mime_type.includes('webm') && f.url);
      
      // 4K / 1080p Video Format
      const videoFormat = adaptiveFormats.find(f => f.has_video && f.url);
      
      return {
        title: info.basic_info.title,
        audioUrl: audioFormat ? audioFormat.url : null,
        videoUrl: videoFormat ? videoFormat.url : null,
        audioBitrate: audioFormat ? audioFormat.bitrate : null,
        videoQuality: videoFormat ? videoFormat.quality_label : null
      };
    })()
  `;

  const streamInfo = await vm.runInContext(testScript, context, { filename: 'playback_test.js' });
  
  if (streamInfo.audioUrl) {
    testFFmpegChunk(streamInfo.audioUrl, "WebM Opus Audio", `${streamInfo.title} (Opus Audio)`, "test_audio.webm");
  }

  if (streamInfo.videoUrl) {
    testFFmpegChunk(streamInfo.videoUrl, "VP9 4K Video", `${streamInfo.title} (${streamInfo.videoQuality} Video)`, "test_video.webm");
  }
}

runPlaybackTest();
