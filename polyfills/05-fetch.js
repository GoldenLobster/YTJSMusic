// polyfills/05-fetch.js
// Polyfills for fetch, Headers, Request, and Response in JavaScriptCore

(function(global) {
  if (typeof global.Headers === 'undefined') {
    global.Headers = class Headers {
      constructor(init = {}) {
        this._map = new Map();
        if (init) {
          if (init instanceof Headers) {
            init.forEach((v, k) => this.append(k, v));
          } else if (Array.isArray(init)) {
            for (const [k, v] of init) this.append(k, v);
          } else if (typeof init === 'object') {
            for (const k of Object.keys(init)) this.append(k, init[k]);
          }
        }
      }

      append(name, value) {
        const key = String(name).toLowerCase();
        const strVal = String(value);
        if (this._map.has(key)) {
          this._map.set(key, this._map.get(key) + ', ' + strVal);
        } else {
          this._map.set(key, strVal);
        }
      }

      delete(name) {
        this._map.delete(String(name).toLowerCase());
      }

      get(name) {
        return this._map.get(String(name).toLowerCase()) || null;
      }

      has(name) {
        return this._map.has(String(name).toLowerCase());
      }

      set(name, value) {
        this._map.set(String(name).toLowerCase(), String(value));
      }

      forEach(callback, thisArg) {
        this._map.forEach((v, k) => callback.call(thisArg, v, k, this));
      }

      *entries() {
        for (const [k, v] of this._map.entries()) {
          yield [k, v];
        }
      }

      *keys() {
        for (const k of this._map.keys()) {
          yield k;
        }
      }

      *values() {
        for (const v of this._map.values()) {
          yield v;
        }
      }

      [Symbol.iterator]() {
        return this.entries();
      }
    };
  }

  if (typeof global.Response === 'undefined') {
    global.Response = class Response {
      constructor(body = null, init = {}) {
        this._body = body;
        this.status = typeof init.status === 'number' ? init.status : 200;
        this.statusText = init.statusText || 'OK';
        this.ok = this.status >= 200 && this.status < 300;
        this.headers = new global.Headers(init.headers);
        this.url = init.url || '';
      }

      async text() {
        if (typeof this._body === 'string') return this._body;
        if (this._body instanceof Uint8Array || ArrayBuffer.isView(this._body)) {
          return new global.TextDecoder().decode(this._body);
        }
        if (this._body instanceof ArrayBuffer) {
          return new global.TextDecoder().decode(new Uint8Array(this._body));
        }
        return String(this._body || '');
      }

      async json() {
        const text = await this.text();
        return JSON.parse(text);
      }

      async arrayBuffer() {
        if (this._body instanceof ArrayBuffer) return this._body;
        if (this._body instanceof Uint8Array) {
          return this._body.buffer.slice(this._body.byteOffset, this._body.byteOffset + this._body.byteLength);
        }
        if (ArrayBuffer.isView(this._body)) {
          return this._body.buffer.slice(this._body.byteOffset, this._body.byteOffset + this._body.byteLength);
        }
        const str = await this.text();
        return new global.TextEncoder().encode(str).buffer;
      }

      clone() {
        return new Response(this._body, {
          status: this.status,
          statusText: this.statusText,
          headers: this.headers,
          url: this.url
        });
      }
    };
  }

  if (typeof global.Request === 'undefined') {
    global.Request = class Request {
      constructor(input, init = {}) {
        if (input instanceof Request) {
          this.url = input.url;
          this.method = init.method || input.method || 'GET';
          this.headers = new global.Headers(init.headers || input.headers);
          this.body = init.body !== undefined ? init.body : input.body;
          this.signal = init.signal || input.signal;
        } else {
          this.url = String(input);
          this.method = (init.method || 'GET').toUpperCase();
          this.headers = new global.Headers(init.headers);
          this.body = init.body || null;
          this.signal = init.signal || null;
        }
      }

      async text() {
        if (typeof this.body === 'string') return this.body;
        if (this.body instanceof Uint8Array) return new global.TextDecoder().decode(this.body);
        return String(this.body || '');
      }

      async json() {
        return JSON.parse(await this.text());
      }

      async arrayBuffer() {
        const str = await this.text();
        return new global.TextEncoder().encode(str).buffer;
      }
    };
  }

  if (typeof global.fetch === 'undefined') {
    global.fetch = async function fetch(input, init = {}) {
      const request = new global.Request(input, init);
      
      if (typeof global.__nativeFetch !== 'function') {
        throw new Error("Native fetch bridge '__nativeFetch' is not implemented.");
      }

      let bodyData = null;
      if (request.body) {
        if (typeof request.body === 'string') {
          bodyData = request.body;
        } else if (request.body instanceof Uint8Array) {
          bodyData = Array.from(request.body);
        } else if (ArrayBuffer.isView(request.body)) {
          bodyData = Array.from(new Uint8Array(request.body.buffer, request.body.byteOffset, request.body.byteLength));
        }
      }

      const headersArray = [];
      request.headers.forEach((v, k) => headersArray.push([k, v]));

      const nativeParams = {
        url: request.url,
        method: request.method,
        headers: headersArray,
        body: bodyData
      };

      const res = await global.__nativeFetch(nativeParams);
      
      let resBody = res.body;
      if (Array.isArray(resBody)) {
        resBody = new Uint8Array(resBody);
      }

      return new global.Response(resBody, {
        status: res.status || 200,
        statusText: res.statusText || 'OK',
        headers: res.headers || [],
        url: request.url
      });
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
