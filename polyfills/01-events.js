// polyfills/01-events.js
// Polyfills for Event, CustomEvent, and EventTarget

(function(global) {
  if (typeof global.Event === 'undefined') {
    global.Event = class Event {
      constructor(type, eventInitDict = {}) {
        this.type = type;
        this.bubbles = !!eventInitDict.bubbles;
        this.cancelable = !!eventInitDict.cancelable;
        this.defaultPrevented = false;
        this.target = null;
        this.currentTarget = null;
        this.timeStamp = Date.now();
      }
      preventDefault() {
        if (this.cancelable) this.defaultPrevented = true;
      }
      stopPropagation() {}
      stopImmediatePropagation() {}
    };
  }

  if (typeof global.CustomEvent === 'undefined') {
    global.CustomEvent = class CustomEvent extends global.Event {
      constructor(type, customEventInitDict = {}) {
        super(type, customEventInitDict);
        this.detail = customEventInitDict.detail !== undefined ? customEventInitDict.detail : null;
      }
    };
  }

  if (typeof global.EventTarget === 'undefined') {
    global.EventTarget = class EventTarget {
      constructor() {
        this._listeners = new Map();
      }

      addEventListener(type, callback, options) {
        if (!callback) return;
        if (!this._listeners.has(type)) {
          this._listeners.set(type, []);
        }
        const listeners = this._listeners.get(type);
        const exists = listeners.some(l => l.callback === callback);
        if (!exists) {
          listeners.push({ callback, once: options && typeof options === 'object' && options.once });
        }
      }

      removeEventListener(type, callback) {
        if (!callback || !this._listeners.has(type)) return;
        const listeners = this._listeners.get(type);
        const index = listeners.findIndex(l => l.callback === callback);
        if (index !== -1) {
          listeners.splice(index, 1);
        }
      }

      dispatchEvent(event) {
        if (!event || !event.type) return true;
        event.target = this;
        event.currentTarget = this;
        const listeners = this._listeners.get(event.type);
        if (listeners) {
          // Copy array to handle removals during dispatch
          const copy = listeners.slice();
          for (const listener of copy) {
            try {
              if (typeof listener.callback === 'function') {
                listener.callback.call(this, event);
              } else if (listener.callback && typeof listener.callback.handleEvent === 'function') {
                listener.callback.handleEvent(event);
              }
            } catch (err) {
              console.error('Error in EventTarget listener:', err);
            }
            if (listener.once) {
              this.removeEventListener(event.type, listener.callback);
            }
          }
        }
        return !event.defaultPrevented;
      }
    };
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
