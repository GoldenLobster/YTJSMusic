// polyfills/02-text-encoding.js
// Polyfills for TextEncoder and TextDecoder in JavaScriptCore

(function(global) {
  if (typeof global.TextEncoder === 'undefined') {
    global.TextEncoder = class TextEncoder {
      constructor(encoding = 'utf-8') {
        const normalized = String(encoding).toLowerCase().replace(/_/g, '-');
        if (normalized !== 'utf-8' && normalized !== 'utf8') {
          throw new RangeError(`TextEncoder only supports 'utf-8' encoding, got '${encoding}'`);
        }
        this.encoding = 'utf-8';
      }

      encode(input = '') {
        const str = String(input);
        const binStr = unescape(encodeURIComponent(str));
        const arr = new Uint8Array(binStr.length);
        for (let i = 0; i < binStr.length; i++) {
          arr[i] = binStr.charCodeAt(i);
        }
        return arr;
      }

      encodeInto(source, destination) {
        const encoded = this.encode(source);
        const len = Math.min(encoded.length, destination.length);
        destination.set(encoded.subarray(0, len));
        return {
          read: len,
          written: len
        };
      }
    };
  }

  if (typeof global.TextDecoder === 'undefined') {
    global.TextDecoder = class TextDecoder {
      constructor(label = 'utf-8', options = {}) {
        this.encoding = String(label).toLowerCase();
        this.fatal = !!options.fatal;
        this.ignoreBOM = !!options.ignoreBOM;
      }

      decode(input, options = {}) {
        if (!input) return '';
        let bytes;
        if (input instanceof Uint8Array) {
          bytes = input;
        } else if (ArrayBuffer.isView(input)) {
          bytes = new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
        } else if (input instanceof ArrayBuffer) {
          bytes = new Uint8Array(input);
        } else {
          bytes = new Uint8Array(input);
        }

        // Fast UTF-8 decode
        let binaryString = '';
        const chunkSize = 8192;
        for (let i = 0; i < bytes.length; i += chunkSize) {
          const chunk = bytes.subarray(i, i + chunkSize);
          binaryString += String.fromCharCode.apply(null, chunk);
        }

        try {
          return decodeURIComponent(escape(binaryString));
        } catch (e) {
          // Fallback if binary string contains invalid utf8 sequences
          return binaryString;
        }
      }
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
