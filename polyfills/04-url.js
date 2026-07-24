// polyfills/04-url.js
// Polyfills for URL and URLSearchParams in JavaScriptCore

(function(global) {
  if (typeof global.URLSearchParams === 'undefined') {
    global.URLSearchParams = class URLSearchParams {
      constructor(init = '') {
        this._entries = [];
        if (typeof init === 'string') {
          if (init.startsWith('?')) init = init.slice(1);
          if (init.length > 0) {
            const pairs = init.split('&');
            for (const pair of pairs) {
              const [key, ...valueParts] = pair.split('=');
              const value = valueParts.join('=');
              this.append(decodeURIComponent(key.replace(/\+/g, ' ')), decodeURIComponent(value.replace(/\+/g, ' ')));
            }
          }
        } else if (Array.isArray(init)) {
          for (const [key, value] of init) {
            this.append(key, value);
          }
        } else if (init && typeof init === 'object') {
          for (const key of Object.keys(init)) {
            this.append(key, init[key]);
          }
        }
      }

      append(name, value) {
        this._entries.push([String(name), String(value)]);
      }

      delete(name) {
        const strName = String(name);
        this._entries = this._entries.filter(([k]) => k !== strName);
      }

      get(name) {
        const strName = String(name);
        const entry = this._entries.find(([k]) => k === strName);
        return entry ? entry[1] : null;
      }

      getAll(name) {
        const strName = String(name);
        return this._entries.filter(([k]) => k === strName).map(([, v]) => v);
      }

      has(name) {
        const strName = String(name);
        return this._entries.some(([k]) => k === strName);
      }

      set(name, value) {
        const strName = String(name);
        const strVal = String(value);
        let found = false;
        this._entries = this._entries.filter(([k]) => {
          if (k === strName) {
            if (!found) {
              found = true;
              return true;
            }
            return false;
          }
          return true;
        });
        if (found) {
          const idx = this._entries.findIndex(([k]) => k === strName);
          if (idx !== -1) this._entries[idx][1] = strVal;
        } else {
          this.append(strName, strVal);
        }
      }

      sort() {
        this._entries.sort(([a], [b]) => a.localeCompare(b));
      }

      toString() {
        return this._entries
          .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
          .join('&');
      }

      *entries() {
        for (const entry of this._entries) {
          yield [entry[0], entry[1]];
        }
      }

      *keys() {
        for (const entry of this._entries) {
          yield entry[0];
        }
      }

      *values() {
        for (const entry of this._entries) {
          yield entry[1];
        }
      }

      forEach(callback, thisArg) {
        for (const [k, v] of this._entries) {
          callback.call(thisArg, v, k, this);
        }
      }

      [Symbol.iterator]() {
        return this.entries();
      }
    };
  }

  if (typeof global.URL === 'undefined') {
    global.URL = class URL {
      constructor(url, base) {
        let fullUrl = String(url);
        if (base) {
          const baseUrl = String(base);
          if (!fullUrl.includes('://')) {
            if (fullUrl.startsWith('/')) {
              const baseOriginMatch = baseUrl.match(/^([a-z0-9+\-.]+:\/\/[^\/]+)/i);
              fullUrl = (baseOriginMatch ? baseOriginMatch[1] : baseUrl) + fullUrl;
            } else {
              const baseDirMatch = baseUrl.match(/^([a-z0-9+\-.]+:\/\/.*\/)/i);
              fullUrl = (baseDirMatch ? baseDirMatch[1] : baseUrl + '/') + fullUrl;
            }
          }
        }

        const match = fullUrl.match(/^([a-z0-9+\-.]+):\/\/([^/?#]*)([^?#]*)(?:\?([^#]*))?(?:#(.*))?$/i);
        if (!match) {
          throw new TypeError(`Invalid URL: ${fullUrl}`);
        }

        this.protocol = match[1].toLowerCase() + ':';
        this.host = match[2];
        const hostPortMatch = this.host.split(':');
        this.hostname = hostPortMatch[0];
        this.port = hostPortMatch[1] || '';
        this.pathname = match[3] || '/';
        this.search = match[4] ? '?' + match[4] : '';
        this.hash = match[5] ? '#' + match[5] : '';
        this._searchParams = new global.URLSearchParams(match[4] || '');
      }

      get href() {
        return `${this.protocol}//${this.host}${this.pathname}${this.search}${this.hash}`;
      }
      set href(v) {
        const u = new URL(v);
        Object.assign(this, u);
      }

      get origin() {
        return `${this.protocol}//${this.host}`;
      }

      get searchParams() {
        return this._searchParams;
      }

      toString() {
        return this.href;
      }

      toJSON() {
        return this.href;
      }

      static createObjectURL(blob) {
        return `blob:jsc-${Math.random().toString(36).slice(2)}`;
      }

      static revokeObjectURL(url) {}
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
