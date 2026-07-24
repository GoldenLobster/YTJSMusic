// polyfills/06-crypto.js
// Polyfills for Web Crypto API (crypto.getRandomValues, crypto.randomUUID, crypto.subtle) in JavaScriptCore

(function(global) {
  if (typeof global.crypto === 'undefined') {
    global.crypto = {};
  }

  // getRandomValues polyfill
  if (typeof global.crypto.getRandomValues === 'undefined') {
    global.crypto.getRandomValues = function getRandomValues(array) {
      if (!array || !ArrayBuffer.isView(array)) {
        throw new TypeError("crypto.getRandomValues requires an ArrayBufferView");
      }
      if (typeof global.__nativeGetRandomValues === 'function') {
        const randomBytes = global.__nativeGetRandomValues(array.byteLength);
        const view = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
        for (let i = 0; i < randomBytes.length; i++) {
          view[i] = randomBytes[i];
        }
      } else {
        // Pseudo-random fallback if native bridge not attached
        const view = new Uint8Array(array.buffer, array.byteOffset, array.byteLength);
        for (let i = 0; i < view.length; i++) {
          view[i] = Math.floor(Math.random() * 256);
        }
      }
      return array;
    };
  }

  // randomUUID polyfill
  if (typeof global.crypto.randomUUID === 'undefined') {
    global.crypto.randomUUID = function randomUUID() {
      if (typeof global.__nativeRandomUUID === 'function') {
        return global.__nativeRandomUUID();
      }
      // v4 UUID generation
      return '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, c =>
        (c ^ (global.crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))).toString(16)
      );
    };
  }

  // SubtleCrypto polyfill
  if (typeof global.crypto.subtle === 'undefined') {
    global.crypto.subtle = {
      digest: async function digest(algorithm, data) {
        let algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;
        algoName = algoName.toUpperCase().replace('-', ''); // e.g. SHA1, SHA256

        let bytes;
        if (data instanceof Uint8Array) {
          bytes = data;
        } else if (ArrayBuffer.isView(data)) {
          bytes = new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
        } else if (data instanceof ArrayBuffer) {
          bytes = new Uint8Array(data);
        } else {
          bytes = new Uint8Array(data);
        }

        if (typeof global.__nativeSubtleDigest === 'function') {
          const resultBytes = await global.__nativeSubtleDigest(algoName, Array.from(bytes));
          return new Uint8Array(resultBytes).buffer;
        }

        throw new Error(`SubtleCrypto.digest natively requires '__nativeSubtleDigest' for algorithm: ${algoName}`);
      },

      importKey: async function importKey(format, keyData, algorithm, extractable, keyUsages) {
        return { format, keyData, algorithm, extractable, keyUsages };
      },

      sign: async function sign(algorithm, key, data) {
        let algoName = typeof algorithm === 'string' ? algorithm : algorithm.name;
        algoName = algoName.toUpperCase().replace('-', '');
        if (typeof global.__nativeSubtleSign === 'function') {
          const resultBytes = await global.__nativeSubtleSign(algoName, key, Array.from(new Uint8Array(data)));
          return new Uint8Array(resultBytes).buffer;
        }
        throw new Error(`SubtleCrypto.sign requires '__nativeSubtleSign'`);
      }
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
