// polyfills/11-structured-clone.js
// Polyfill for HTML structuredClone algorithm in JavaScriptCore

(function(global) {
  if (typeof global.structuredClone === 'function') {
    return;
  }

  function clone(val, seen) {
    if (val === null || typeof val !== 'object') {
      return val;
    }

    if (seen.has(val)) {
      return seen.get(val);
    }

    if (val instanceof Date) {
      return new Date(val.getTime());
    }

    if (val instanceof RegExp) {
      return new RegExp(val.source, val.flags);
    }

    if (val instanceof Error) {
      const err = new val.constructor(val.message);
      err.stack = val.stack;
      return err;
    }

    if (val instanceof Map) {
      const copy = new Map();
      seen.set(val, copy);
      val.forEach((v, k) => {
        copy.set(clone(k, seen), clone(v, seen));
      });
      return copy;
    }

    if (val instanceof Set) {
      const copy = new Set();
      seen.set(val, copy);
      val.forEach(v => {
        copy.add(clone(v, seen));
      });
      return copy;
    }

    if (ArrayBuffer.isView(val)) {
      if (val instanceof DataView) {
        return new DataView(val.buffer.slice(val.byteOffset, val.byteOffset + val.byteLength));
      }
      return new val.constructor(val.buffer.slice(val.byteOffset, val.byteOffset + val.byteLength));
    }

    if (val instanceof ArrayBuffer) {
      return val.slice(0);
    }

    if (Array.isArray(val)) {
      const copy = [];
      seen.set(val, copy);
      for (let i = 0; i < val.length; i++) {
        copy[i] = clone(val[i], seen);
      }
      return copy;
    }

    // Generic Object
    const proto = Object.getPrototypeOf(val);
    const copy = proto ? Object.create(proto) : Object.create(null);
    seen.set(val, copy);

    const keys = Object.keys(val);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      copy[key] = clone(val[key], seen);
    }

    return copy;
  }

  global.structuredClone = function structuredClone(value) {
    return clone(value, new Map());
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
