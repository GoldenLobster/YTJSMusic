// polyfills/07-timers.js
// Polyfills for timers in JavaScriptCore environment

(function(global) {
  if (typeof global.setTimeout === 'undefined') {
    global.setTimeout = function setTimeout(callback, delay = 0, ...args) {
      if (typeof global.__nativeSetTimeout === 'function') {
        return global.__nativeSetTimeout(() => callback(...args), delay);
      }
      return 0;
    };
  }

  if (typeof global.clearTimeout === 'undefined') {
    global.clearTimeout = function clearTimeout(id) {
      if (typeof global.__nativeClearTimeout === 'function') {
        global.__nativeClearTimeout(id);
      }
    };
  }

  if (typeof global.setInterval === 'undefined') {
    global.setInterval = function setInterval(callback, delay = 0, ...args) {
      if (typeof global.__nativeSetInterval === 'function') {
        return global.__nativeSetInterval(() => callback(...args), delay);
      }
      return 0;
    };
  }

  if (typeof global.clearInterval === 'undefined') {
    global.clearInterval = function clearInterval(id) {
      if (typeof global.__nativeClearInterval === 'function') {
        global.__nativeClearInterval(id);
      }
    };
  }

  if (typeof global.queueMicrotask === 'undefined') {
    global.queueMicrotask = function queueMicrotask(callback) {
      Promise.resolve().then(callback).catch(err => {
        setTimeout(() => { throw err; }, 0);
      });
    };
  }

  if (typeof global.setImmediate === 'undefined') {
    global.setImmediate = function setImmediate(callback, ...args) {
      return global.setTimeout(callback, 0, ...args);
    };
  }

  if (typeof global.clearImmediate === 'undefined') {
    global.clearImmediate = function clearImmediate(id) {
      global.clearTimeout(id);
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
