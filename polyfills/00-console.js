// polyfills/00-console.js
// Minimal console polyfill for JavaScriptCore environment

(function(global) {
  const formatArg = (a) => {
    if (a === null) return 'null';
    if (a === undefined) return 'undefined';
    if (typeof a === 'object') {
      try {
        return JSON.stringify(a, null, 2);
      } catch (e) {
        return String(a);
      }
    }
    return String(a);
  };

  const makeLogFn = (level) => function(...args) {
    const formatted = args.map(formatArg).join(' ');
    if (typeof global.__nativeLog === 'function') {
      global.__nativeLog(level, formatted);
    }
  };

  global.console = global.console || {};
  global.console.log = makeLogFn('LOG');
  global.console.info = makeLogFn('INFO');
  global.console.warn = makeLogFn('WARN');
  global.console.error = makeLogFn('ERROR');
  global.console.debug = makeLogFn('DEBUG');
})(typeof globalThis !== 'undefined' ? globalThis : this);
