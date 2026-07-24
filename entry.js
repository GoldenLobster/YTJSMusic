import { Innertube, UniversalCache, Platform } from 'youtubei.js/web.bundle';

if (Platform && Platform.shim) {
  Platform.shim.eval = (data, env) => {
    const keys = Object.keys(env);
    const vals = Object.values(env);
    const code = data.output;
    const fn = new Function(...keys, code);
    return fn(...vals);
  };
}

globalThis.Innertube = Innertube;
globalThis.UniversalCache = UniversalCache;
globalThis.Platform = Platform;
