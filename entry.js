import { Innertube, UniversalCache, Platform } from 'youtubei.js/web.bundle';
import { AppleMusic, AuthType, Region } from '@syncfm/applemusic-api';

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
globalThis.AppleMusic = AppleMusic;
globalThis.AuthType = AuthType;
globalThis.Region = Region;
