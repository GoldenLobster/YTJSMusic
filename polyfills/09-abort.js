// polyfills/09-abort.js
// Polyfills for AbortController and AbortSignal in JavaScriptCore

(function(global) {
  if (typeof global.AbortSignal === 'undefined') {
    global.AbortSignal = class AbortSignal extends global.EventTarget {
      constructor() {
        super();
        this.aborted = false;
        this.reason = undefined;
        this.onabort = null;
      }

      static abort(reason) {
        const signal = new AbortSignal();
        signal.aborted = true;
        signal.reason = reason !== undefined ? reason : new Error('Aborted');
        return signal;
      }

      static timeout(ms) {
        const controller = new global.AbortController();
        setTimeout(() => {
          controller.abort(new Error(`Timeout of ${ms}ms exceeded`));
        }, ms);
        return controller.signal;
      }
    };
  }

  if (typeof global.AbortController === 'undefined') {
    global.AbortController = class AbortController {
      constructor() {
        this.signal = new global.AbortSignal();
      }

      abort(reason) {
        if (this.signal.aborted) return;
        this.signal.aborted = true;
        this.signal.reason = reason !== undefined ? reason : new Error('Aborted');
        const event = new global.Event('abort');
        if (typeof this.signal.onabort === 'function') {
          this.signal.onabort.call(this.signal, event);
        }
        this.signal.dispatchEvent(event);
      }
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
