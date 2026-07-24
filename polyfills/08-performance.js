// polyfills/08-performance.js
// Polyfill for performance.now() in JavaScriptCore

(function(global) {
  if (typeof global.performance === 'undefined') {
    const startTime = Date.now();
    global.performance = {
      now: function now() {
        if (typeof global.__nativePerformanceNow === 'function') {
          return global.__nativePerformanceNow();
        }
        return Date.now() - startTime;
      },
      timeOrigin: startTime
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
