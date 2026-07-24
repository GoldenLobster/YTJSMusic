/**
 * @license
 * web-streams-polyfill v4.3.0
 * Copyright 2026 Mattias Buelens, Diwank Singh Tomer and other contributors.
 * This code is released under the MIT license.
 * SPDX-License-Identifier: MIT
 */
!(function() {
  "use strict";
  var e = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? Symbol : function(e2) {
    return "Symbol(".concat(e2, ")");
  };
  function r() {
  }
  function t(e2) {
    return "object" == typeof e2 && null !== e2 || "function" == typeof e2;
  }
  "function" == typeof SuppressedError && SuppressedError;
  var o = r;
  function n(e2, r2) {
    try {
      Object.defineProperty(e2, "name", { value: r2, configurable: true });
    } catch (e3) {
    }
  }
  var i = Promise, a = Promise.resolve.bind(i), u = Promise.prototype.then, l = Promise.reject.bind(i), s = a;
  function c(e2) {
    return new i(e2);
  }
  function f(e2) {
    return c(function(r2) {
      return r2(e2);
    });
  }
  function d(e2) {
    return l(e2);
  }
  function p(e2, r2, t2) {
    return u.call(e2, r2, t2);
  }
  function b(e2, r2, t2) {
    p(p(e2, r2, t2), void 0, o);
  }
  function h(e2, r2) {
    b(e2, r2);
  }
  function _(e2, r2) {
    b(e2, void 0, r2);
  }
  function m(e2, r2, t2) {
    return p(e2, r2, t2);
  }
  function v(e2) {
    p(e2, void 0, o);
  }
  var y = function(e2) {
    if ("function" == typeof queueMicrotask) y = queueMicrotask;
    else {
      var r2 = f(void 0);
      y = function(e3) {
        return p(r2, e3);
      };
    }
    return y(e2);
  };
  function g(e2, r2, t2) {
    if ("function" != typeof e2) throw new TypeError("Argument is not a function");
    return Function.prototype.apply.call(e2, r2, t2);
  }
  function S(e2, r2, t2) {
    try {
      return f(g(e2, r2, t2));
    } catch (e3) {
      return d(e3);
    }
  }
  var w = (function() {
    function e2() {
      this._cursor = 0, this._size = 0, this._front = { _elements: [], _next: void 0 }, this._back = this._front, this._cursor = 0, this._size = 0;
    }
    return Object.defineProperty(e2.prototype, "length", { get: function() {
      return this._size;
    }, enumerable: false, configurable: true }), e2.prototype.push = function(e3) {
      var r2 = this._back, t2 = r2;
      16383 === r2._elements.length && (t2 = { _elements: [], _next: void 0 }), r2._elements.push(e3), t2 !== r2 && (this._back = t2, r2._next = t2), ++this._size;
    }, e2.prototype.shift = function() {
      var e3 = this._front, r2 = e3, t2 = this._cursor, o2 = t2 + 1, n2 = e3._elements, i2 = n2[t2];
      return 16384 === o2 && (r2 = e3._next, o2 = 0), --this._size, this._cursor = o2, e3 !== r2 && (this._front = r2), n2[t2] = void 0, i2;
    }, e2.prototype.forEach = function(e3) {
      for (var r2 = this._cursor, t2 = this._front, o2 = t2._elements; !(r2 === o2.length && void 0 === t2._next || r2 === o2.length && (r2 = 0, 0 === (o2 = (t2 = t2._next)._elements).length)); ) e3(o2[r2]), ++r2;
    }, e2.prototype.peek = function() {
      var e3 = this._front, r2 = this._cursor;
      return e3._elements[r2];
    }, e2;
  })(), R = e("[[AbortSteps]]"), T = e("[[ErrorSteps]]"), P = e("[[CancelSteps]]"), C = e("[[PullSteps]]"), q = e("[[CanPullSyncSteps]]"), E = e("[[ReleaseSteps]]");
  function O(e2, r2) {
    e2._ownerReadableStream = r2, r2._reader = e2, "readable" === r2._state ? k(e2) : "closed" === r2._state ? (function(e3) {
      k(e3), D(e3);
    })(e2) : A(e2, r2._storedError);
  }
  function W(e2, r2) {
    return $t(e2._ownerReadableStream, r2);
  }
  function j(e2) {
    var r2 = e2._ownerReadableStream;
    "readable" === r2._state ? z(e2, new TypeError("Reader was released and can no longer be used to monitor the stream's closedness")) : (function(e3, r3) {
      A(e3, r3);
    })(e2, new TypeError("Reader was released and can no longer be used to monitor the stream's closedness")), r2._readableStreamController[E](), r2._reader = void 0, e2._ownerReadableStream = void 0;
  }
  function B(e2) {
    return new TypeError("Cannot " + e2 + " a stream using a released reader");
  }
  function k(e2) {
    e2._closedPromise = c(function(r2, t2) {
      e2._closedPromise_resolve = r2, e2._closedPromise_reject = t2;
    });
  }
  function A(e2, r2) {
    k(e2), z(e2, r2);
  }
  function z(e2, r2) {
    void 0 !== e2._closedPromise_reject && (v(e2._closedPromise), e2._closedPromise_reject(r2), e2._closedPromise_resolve = void 0, e2._closedPromise_reject = void 0);
  }
  function D(e2) {
    void 0 !== e2._closedPromise_resolve && (e2._closedPromise_resolve(void 0), e2._closedPromise_resolve = void 0, e2._closedPromise_reject = void 0);
  }
  var F = Number.isFinite || function(e2) {
    return "number" == typeof e2 && isFinite(e2);
  }, L = Math.trunc || function(e2) {
    return e2 < 0 ? Math.ceil(e2) : Math.floor(e2);
  };
  function I(e2, r2) {
    if (void 0 !== e2 && ("object" != typeof (t2 = e2) && "function" != typeof t2)) throw new TypeError("".concat(r2, " is not an object."));
    var t2;
  }
  function M(e2, r2) {
    if ("function" != typeof e2) throw new TypeError("".concat(r2, " is not a function."));
  }
  function Y(e2, r2) {
    if (!/* @__PURE__ */ (function(e3) {
      return "object" == typeof e3 && null !== e3 || "function" == typeof e3;
    })(e2)) throw new TypeError("".concat(r2, " is not an object."));
  }
  function x(e2, r2, t2) {
    if (void 0 === e2) throw new TypeError("Parameter ".concat(r2, " is required in '").concat(t2, "'."));
  }
  function Q(e2, r2, t2) {
    if (void 0 === e2) throw new TypeError("".concat(r2, " is required in '").concat(t2, "'."));
  }
  function N(e2) {
    return Number(e2);
  }
  function H(e2) {
    return 0 === e2 ? 0 : e2;
  }
  function V(e2, r2) {
    var t2 = Number.MAX_SAFE_INTEGER, o2 = Number(e2);
    if (o2 = H(o2), !F(o2)) throw new TypeError("".concat(r2, " is not a finite number"));
    if ((o2 = (function(e3) {
      return H(L(e3));
    })(o2)) < 0 || o2 > t2) throw new TypeError("".concat(r2, " is outside the accepted range of ").concat(0, " to ").concat(t2, ", inclusive"));
    return F(o2) && 0 !== o2 ? o2 : 0;
  }
  function U(e2, r2) {
    if (!Kt(e2)) throw new TypeError("".concat(r2, " is not a ReadableStream."));
  }
  function G(e2) {
    return new $(e2);
  }
  function X(e2, r2) {
    e2._reader._readRequests.push(r2);
  }
  function J(e2, r2, t2) {
    var o2 = e2._reader._readRequests.shift();
    t2 ? o2._closeSteps() : o2._chunkSteps(r2);
  }
  function K(e2) {
    return e2._reader._readRequests.length;
  }
  function Z(e2) {
    var r2 = e2._reader;
    return void 0 !== r2 && !!ie(r2);
  }
  var $ = (function() {
    function ReadableStreamDefaultReader(e2) {
      if (x(e2, 1, "ReadableStreamDefaultReader"), U(e2, "First parameter"), Zt(e2)) throw new TypeError("This stream has already been locked for exclusive reading by another reader");
      O(this, e2), this._readRequests = new w();
    }
    return Object.defineProperty(ReadableStreamDefaultReader.prototype, "closed", { get: function() {
      return ie(this) ? this._closedPromise : d(se("closed"));
    }, enumerable: false, configurable: true }), ReadableStreamDefaultReader.prototype.cancel = function(e2) {
      return void 0 === e2 && (e2 = void 0), ie(this) ? void 0 === this._ownerReadableStream ? d(B("cancel")) : W(this, e2) : d(se("cancel"));
    }, ReadableStreamDefaultReader.prototype.read = function() {
      if (!ie(this)) return d(se("read"));
      if (void 0 === this._ownerReadableStream) return d(B("read from"));
      var e2 = ue(this) ? new ne() : new oe();
      return ae(this, e2), e2._promise;
    }, ReadableStreamDefaultReader.prototype.releaseLock = function() {
      if (!ie(this)) throw se("releaseLock");
      void 0 !== this._ownerReadableStream && (function(e2) {
        j(e2);
        var r2 = new TypeError("Reader was released");
        le(e2, r2);
      })(this);
    }, ReadableStreamDefaultReader;
  })();
  Object.defineProperties($.prototype, { cancel: { enumerable: true }, read: { enumerable: true }, releaseLock: { enumerable: true }, closed: { enumerable: true } }), n($.prototype.cancel, "cancel"), n($.prototype.read, "read"), n($.prototype.releaseLock, "releaseLock"), "symbol" == typeof e.toStringTag && Object.defineProperty($.prototype, e.toStringTag, { value: "ReadableStreamDefaultReader", configurable: true });
  var ee, re, te, oe = (function() {
    function e2() {
      var e3 = this;
      this._promise = c(function(r2, t2) {
        e3._resolvePromise = r2, e3._rejectPromise = t2;
      });
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._resolvePromise({ value: e3, done: false });
    }, e2.prototype._closeSteps = function() {
      this._resolvePromise({ value: void 0, done: true });
    }, e2.prototype._errorSteps = function(e3) {
      this._rejectPromise(e3);
    }, e2;
  })(), ne = (function() {
    function e2() {
      this._promise = void 0;
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._promise = s({ value: e3, done: false });
    }, e2.prototype._closeSteps = function() {
      this._promise = s({ value: void 0, done: true });
    }, e2.prototype._errorSteps = function(e3) {
      this._promise = d(e3);
    }, e2;
  })();
  function ie(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_readRequests") && e2 instanceof $);
  }
  function ae(e2, r2) {
    var t2 = e2._ownerReadableStream;
    t2._disturbed = true, "closed" === t2._state ? r2._closeSteps() : "errored" === t2._state ? r2._errorSteps(t2._storedError) : t2._readableStreamController[C](r2);
  }
  function ue(e2) {
    var r2 = e2._ownerReadableStream;
    return "closed" === r2._state || ("errored" === r2._state || r2._readableStreamController[q]());
  }
  function le(e2, r2) {
    var t2 = e2._readRequests;
    e2._readRequests = new w(), t2.forEach(function(e3) {
      e3._errorSteps(r2);
    });
  }
  function se(e2) {
    return new TypeError("ReadableStreamDefaultReader.prototype.".concat(e2, " can only be used on a ReadableStreamDefaultReader"));
  }
  function ce(e2) {
    return e2.slice();
  }
  function fe(e2, r2, t2, o2, n2) {
    new Uint8Array(e2).set(new Uint8Array(t2, o2, n2), r2);
  }
  var de = function(e2) {
    return (de = "function" == typeof e2.transfer ? function(e3) {
      return e3.transfer();
    } : "function" == typeof structuredClone ? function(e3) {
      return structuredClone(e3, { transfer: [e3] });
    } : function(e3) {
      return e3;
    })(e2);
  }, pe = function(e2) {
    return (pe = "boolean" == typeof e2.detached ? function(e3) {
      return e3.detached;
    } : function(e3) {
      return 0 === e3.byteLength;
    })(e2);
  };
  function be(e2, r2, t2) {
    if (e2.slice) return e2.slice(r2, t2);
    var o2 = t2 - r2, n2 = new ArrayBuffer(o2);
    return fe(n2, 0, e2, r2, o2), n2;
  }
  function he(e2, r2) {
    var t2 = e2[r2];
    if (null != t2) {
      if ("function" != typeof t2) throw new TypeError("".concat(String(r2), " is not a function"));
      return t2;
    }
  }
  function _e(e2) {
    try {
      var r2 = e2.done, t2 = e2.value;
      return p(s(t2), function(e3) {
        return { done: r2, value: e3 };
      });
    } catch (e3) {
      return d(e3);
    }
  }
  var me, ve = null !== (te = null !== (ee = e.asyncIterator) && void 0 !== ee ? ee : null === (re = e.for) || void 0 === re ? void 0 : re.call(e, "Symbol.asyncIterator")) && void 0 !== te ? te : "@@asyncIterator";
  function ye(r2, o2, n2) {
    if (void 0 === o2 && (o2 = "sync"), void 0 === n2) if ("async" === o2) {
      if (void 0 === (n2 = he(r2, ve))) return (function(e2) {
        var r3 = { next: function() {
          var r4;
          try {
            r4 = ge(e2);
          } catch (e3) {
            return d(e3);
          }
          return _e(r4);
        }, return: function(r4) {
          var o3;
          try {
            var n3 = he(e2.iterator, "return");
            if (void 0 === n3) return f({ done: true, value: r4 });
            o3 = g(n3, e2.iterator, [r4]);
          } catch (e3) {
            return d(e3);
          }
          return t(o3) ? _e(o3) : d(new TypeError("The iterator.return() method must return an object"));
        } };
        return { iterator: r3, nextMethod: r3.next, done: false };
      })(ye(r2, "sync", he(r2, e.iterator)));
    } else n2 = he(r2, e.iterator);
    if (void 0 === n2) throw new TypeError("The object is not iterable");
    var i2 = g(n2, r2, []);
    if (!t(i2)) throw new TypeError("The iterator method must return an object");
    return { iterator: i2, nextMethod: i2.next, done: false };
  }
  function ge(e2) {
    var r2 = g(e2.nextMethod, e2.iterator, []);
    if (!t(r2)) throw new TypeError("The iterator.next() method must return an object");
    return r2;
  }
  var Se = (function() {
    function e2(e3, r2) {
      this._ongoingPromise = void 0, this._isFinished = false, this._reader = e3, this._preventCancel = r2;
    }
    return e2.prototype.next = function() {
      var e3 = this, r2 = function() {
        return e3._nextSteps();
      };
      return this._ongoingPromise = this._ongoingPromise ? m(this._ongoingPromise, r2, r2) : r2(), this._ongoingPromise;
    }, e2.prototype.return = function(e3) {
      var r2 = this, t2 = function() {
        return r2._returnSteps(e3);
      };
      return this._ongoingPromise = this._ongoingPromise ? m(this._ongoingPromise, t2, t2) : t2(), this._ongoingPromise;
    }, e2.prototype._nextSteps = function() {
      if (this._isFinished) return Promise.resolve({ value: void 0, done: true });
      var e3 = this._reader, r2 = new we(this);
      return ae(e3, r2), r2._promise;
    }, e2.prototype._returnSteps = function(e3) {
      if (this._isFinished) return Promise.resolve({ value: e3, done: true });
      this._isFinished = true;
      var r2 = this._reader;
      if (!this._preventCancel) {
        var t2 = W(r2, e3);
        return j(r2), m(t2, function() {
          return { value: e3, done: true };
        });
      }
      return j(r2), f({ value: e3, done: true });
    }, e2;
  })(), we = (function() {
    function e2(e3) {
      var r2 = this;
      this._iterator = e3, this._promise = c(function(e4, t2) {
        r2._resolvePromise = e4, r2._rejectPromise = t2;
      });
    }
    return e2.prototype._chunkSteps = function(e3) {
      var r2 = this;
      this._iterator._ongoingPromise = void 0, y(function() {
        return r2._resolvePromise({ value: e3, done: false });
      });
    }, e2.prototype._closeSteps = function() {
      var e3 = this._iterator;
      e3._ongoingPromise = void 0, e3._isFinished = true, j(e3._reader), this._resolvePromise({ value: void 0, done: true });
    }, e2.prototype._errorSteps = function(e3) {
      var r2 = this._iterator;
      r2._ongoingPromise = void 0, r2._isFinished = true, j(r2._reader), this._rejectPromise(e3);
    }, e2;
  })(), Re = ((me = { next: function() {
    return Te(this) ? this._asyncIteratorImpl.next() : d(Pe("next"));
  }, return: function(e2) {
    return Te(this) ? this._asyncIteratorImpl.return(e2) : d(Pe("return"));
  } })[ve] = function() {
    return this;
  }, me);
  function Te(e2) {
    if (!t(e2)) return false;
    if (!Object.prototype.hasOwnProperty.call(e2, "_asyncIteratorImpl")) return false;
    try {
      return e2._asyncIteratorImpl instanceof Se;
    } catch (e3) {
      return false;
    }
  }
  function Pe(e2) {
    return new TypeError("ReadableStreamAsyncIterator.".concat(e2, " can only be used on a ReadableSteamAsyncIterator"));
  }
  Object.defineProperty(Re, ve, { enumerable: false });
  var Ce = Number.isNaN || function(e2) {
    return e2 != e2;
  };
  function qe(e2) {
    var r2 = be(e2.buffer, e2.byteOffset, e2.byteOffset + e2.byteLength);
    return new Uint8Array(r2);
  }
  function Ee(e2) {
    var r2 = e2._queue.shift();
    return e2._queueTotalSize -= r2.size, e2._queueTotalSize < 0 && (e2._queueTotalSize = 0), r2.value;
  }
  function Oe(e2, r2, t2) {
    if ("number" != typeof (o2 = t2) || Ce(o2) || o2 < 0 || t2 === 1 / 0) throw new RangeError("Size must be a finite, non-NaN, non-negative number.");
    var o2;
    e2._queue.push({ value: r2, size: t2 }), e2._queueTotalSize += t2;
  }
  function We(e2) {
    e2._queue = new w(), e2._queueTotalSize = 0;
  }
  function je(e2) {
    return e2 === DataView;
  }
  function Be(e2) {
    return je(e2) ? 1 : e2.BYTES_PER_ELEMENT;
  }
  var ke = (function() {
    function ReadableStreamBYOBRequest() {
      throw new TypeError("Illegal constructor");
    }
    return Object.defineProperty(ReadableStreamBYOBRequest.prototype, "view", { get: function() {
      if (!De(this)) throw lr("view");
      return this._view;
    }, enumerable: false, configurable: true }), ReadableStreamBYOBRequest.prototype.respond = function(e2) {
      if (!De(this)) throw lr("respond");
      if (x(e2, 1, "respond"), e2 = V(e2, "First parameter"), void 0 === this._associatedReadableByteStreamController) throw new TypeError("This BYOB request has been invalidated");
      if (pe(this._view.buffer)) throw new TypeError("The BYOB request's buffer has been detached and so cannot be used as a response");
      ir(this._associatedReadableByteStreamController, e2);
    }, ReadableStreamBYOBRequest.prototype.respondWithNewView = function(e2) {
      if (!De(this)) throw lr("respondWithNewView");
      if (x(e2, 1, "respondWithNewView"), !ArrayBuffer.isView(e2)) throw new TypeError("You can only respond with array buffer views");
      if (void 0 === this._associatedReadableByteStreamController) throw new TypeError("This BYOB request has been invalidated");
      if (pe(e2.buffer)) throw new TypeError("The given view's buffer has been detached and so cannot be used as a response");
      ar(this._associatedReadableByteStreamController, e2);
    }, ReadableStreamBYOBRequest;
  })();
  Object.defineProperties(ke.prototype, { respond: { enumerable: true }, respondWithNewView: { enumerable: true }, view: { enumerable: true } }), n(ke.prototype.respond, "respond"), n(ke.prototype.respondWithNewView, "respondWithNewView"), "symbol" == typeof e.toStringTag && Object.defineProperty(ke.prototype, e.toStringTag, { value: "ReadableStreamBYOBRequest", configurable: true });
  var Ae = (function() {
    function ReadableByteStreamController() {
      throw new TypeError("Illegal constructor");
    }
    return Object.defineProperty(ReadableByteStreamController.prototype, "byobRequest", { get: function() {
      if (!ze(this)) throw sr("byobRequest");
      return or(this);
    }, enumerable: false, configurable: true }), Object.defineProperty(ReadableByteStreamController.prototype, "desiredSize", { get: function() {
      if (!ze(this)) throw sr("desiredSize");
      return nr(this);
    }, enumerable: false, configurable: true }), ReadableByteStreamController.prototype.close = function() {
      if (!ze(this)) throw sr("close");
      if (this._closeRequested) throw new TypeError("The stream has already been closed; do not close it again!");
      var e2 = this._controlledReadableByteStream._state;
      if ("readable" !== e2) throw new TypeError("The stream (in ".concat(e2, " state) is not in the readable state and cannot be closed"));
      $e(this);
    }, ReadableByteStreamController.prototype.enqueue = function(e2) {
      if (!ze(this)) throw sr("enqueue");
      if (x(e2, 1, "enqueue"), !ArrayBuffer.isView(e2)) throw new TypeError("chunk must be an array buffer view");
      if (0 === e2.byteLength) throw new TypeError("chunk must have non-zero byteLength");
      if (0 === e2.buffer.byteLength) throw new TypeError("chunk's buffer must have non-zero byteLength");
      if (this._closeRequested) throw new TypeError("stream is closed or draining");
      var r2 = this._controlledReadableByteStream._state;
      if ("readable" !== r2) throw new TypeError("The stream (in ".concat(r2, " state) is not in the readable state and cannot be enqueued to"));
      er(this, e2);
    }, ReadableByteStreamController.prototype.error = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !ze(this)) throw sr("error");
      rr(this, e2);
    }, ReadableByteStreamController.prototype[P] = function(e2) {
      Le(this), We(this);
      var r2 = this._cancelAlgorithm(e2);
      return Ze(this), r2;
    }, ReadableByteStreamController.prototype[C] = function(e2) {
      var r2 = this._controlledReadableByteStream;
      if (this._queueTotalSize > 0) tr(this, e2);
      else {
        var t2 = this._autoAllocateChunkSize;
        if (void 0 !== t2) {
          var o2 = void 0;
          try {
            o2 = new ArrayBuffer(t2);
          } catch (r3) {
            return void e2._errorSteps(r3);
          }
          var n2 = { buffer: o2, bufferByteLength: t2, byteOffset: 0, byteLength: t2, bytesFilled: 0, minimumFill: 1, elementSize: 1, viewConstructor: Uint8Array, readerType: "default" };
          this._pendingPullIntos.push(n2);
        }
        X(r2, e2), Fe(this);
      }
    }, ReadableByteStreamController.prototype[q] = function() {
      return this._queueTotalSize > 0;
    }, ReadableByteStreamController.prototype[E] = function() {
      if (this._pendingPullIntos.length > 0) {
        var e2 = this._pendingPullIntos.peek();
        e2.readerType = "none", this._pendingPullIntos = new w(), this._pendingPullIntos.push(e2);
      }
    }, ReadableByteStreamController;
  })();
  function ze(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_controlledReadableByteStream") && e2 instanceof Ae);
  }
  function De(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_associatedReadableByteStreamController") && e2 instanceof ke);
  }
  function Fe(e2) {
    var r2 = (function(e3) {
      var r3 = e3._controlledReadableByteStream;
      if ("readable" !== r3._state) return false;
      if (e3._closeRequested) return false;
      if (!e3._started) return false;
      if (Z(r3) && K(r3) > 0) return true;
      if (br(r3) && pr(r3) > 0) return true;
      var t2 = nr(e3);
      if (t2 > 0) return true;
      return false;
    })(e2);
    r2 && (e2._pulling ? e2._pullAgain = true : (e2._pulling = true, b(e2._pullAlgorithm(), function() {
      return e2._pulling = false, e2._pullAgain && (e2._pullAgain = false, Fe(e2)), null;
    }, function(r3) {
      return rr(e2, r3), null;
    })));
  }
  function Le(e2) {
    Ge(e2), e2._pendingPullIntos = new w();
  }
  function Ie(e2, r2) {
    var t2 = false;
    "closed" === e2._state && (t2 = true);
    var o2 = Ye(r2);
    "default" === r2.readerType ? J(e2, o2, t2) : (function(e3, r3, t3) {
      var o3 = e3._reader, n2 = o3._readIntoRequests.shift();
      t3 ? n2._closeSteps(r3) : n2._chunkSteps(r3);
    })(e2, o2, t2);
  }
  function Me(e2, r2) {
    for (var t2 = 0; t2 < r2.length; ++t2) Ie(e2, r2[t2]);
  }
  function Ye(e2) {
    var r2 = e2.bytesFilled, t2 = e2.elementSize;
    return new e2.viewConstructor(e2.buffer, e2.byteOffset, r2 / t2);
  }
  function xe(e2, r2, t2, o2) {
    e2._queue.push({ buffer: r2, byteOffset: t2, byteLength: o2 }), e2._queueTotalSize += o2;
  }
  function Qe(e2, r2, t2, o2) {
    var n2;
    try {
      n2 = be(r2, t2, t2 + o2);
    } catch (r3) {
      throw rr(e2, r3), r3;
    }
    xe(e2, n2, 0, o2);
  }
  function Ne(e2, r2) {
    r2.bytesFilled > 0 && Qe(e2, r2.buffer, r2.byteOffset, r2.bytesFilled), Ke(e2);
  }
  function He(e2, r2) {
    var t2 = Math.min(e2._queueTotalSize, r2.byteLength - r2.bytesFilled), o2 = r2.bytesFilled + t2, n2 = t2, i2 = false, a2 = o2 - o2 % r2.elementSize;
    a2 >= r2.minimumFill && (n2 = a2 - r2.bytesFilled, i2 = true);
    for (var u2 = e2._queue; n2 > 0; ) {
      var l2 = u2.peek(), s2 = Math.min(n2, l2.byteLength), c2 = r2.byteOffset + r2.bytesFilled;
      fe(r2.buffer, c2, l2.buffer, l2.byteOffset, s2), l2.byteLength === s2 ? u2.shift() : (l2.byteOffset += s2, l2.byteLength -= s2), e2._queueTotalSize -= s2, Ve(e2, s2, r2), n2 -= s2;
    }
    return i2;
  }
  function Ve(e2, r2, t2) {
    t2.bytesFilled += r2;
  }
  function Ue(e2) {
    0 === e2._queueTotalSize && e2._closeRequested ? (Ze(e2), eo(e2._controlledReadableByteStream)) : Fe(e2);
  }
  function Ge(e2) {
    null !== e2._byobRequest && (e2._byobRequest._associatedReadableByteStreamController = void 0, e2._byobRequest._view = null, e2._byobRequest = null);
  }
  function Xe(e2) {
    for (var r2 = []; e2._pendingPullIntos.length > 0 && 0 !== e2._queueTotalSize; ) {
      var t2 = e2._pendingPullIntos.peek();
      He(e2, t2) && (Ke(e2), r2.push(t2));
    }
    return r2;
  }
  function Je(e2, r2) {
    var t2 = e2._pendingPullIntos.peek();
    Ge(e2), "closed" === e2._controlledReadableByteStream._state ? (function(e3, r3) {
      "none" === r3.readerType && Ke(e3);
      var t3 = e3._controlledReadableByteStream;
      if (br(t3)) {
        for (var o2 = []; o2.length < pr(t3); ) o2.push(Ke(e3));
        Me(t3, o2);
      }
    })(e2, t2) : (function(e3, r3, t3) {
      if (Ve(0, r3, t3), "none" !== t3.readerType) {
        if (!(t3.bytesFilled < t3.minimumFill)) {
          Ke(e3);
          var o2 = t3.bytesFilled % t3.elementSize;
          if (o2 > 0) {
            var n2 = t3.byteOffset + t3.bytesFilled;
            Qe(e3, t3.buffer, n2 - o2, o2);
          }
          t3.bytesFilled -= o2;
          var i2 = Xe(e3);
          Ie(e3._controlledReadableByteStream, t3), Me(e3._controlledReadableByteStream, i2);
        }
      } else {
        Ne(e3, t3);
        var a2 = Xe(e3);
        Me(e3._controlledReadableByteStream, a2);
      }
    })(e2, r2, t2), Fe(e2);
  }
  function Ke(e2) {
    return e2._pendingPullIntos.shift();
  }
  function Ze(e2) {
    e2._pullAlgorithm = void 0, e2._cancelAlgorithm = void 0;
  }
  function $e(e2) {
    var r2 = e2._controlledReadableByteStream;
    if (!e2._closeRequested && "readable" === r2._state) if (e2._queueTotalSize > 0) e2._closeRequested = true;
    else {
      if (e2._pendingPullIntos.length > 0) {
        var t2 = e2._pendingPullIntos.peek();
        if (t2.bytesFilled % t2.elementSize !== 0) {
          var o2 = new TypeError("Insufficient bytes to fill elements in the given buffer");
          throw rr(e2, o2), o2;
        }
      }
      Ze(e2), eo(r2);
    }
  }
  function er(e2, r2) {
    var t2 = e2._controlledReadableByteStream;
    if (!e2._closeRequested && "readable" === t2._state) {
      var o2 = r2.buffer, n2 = r2.byteOffset, i2 = r2.byteLength;
      if (pe(o2)) throw new TypeError("chunk's buffer is detached and so cannot be enqueued");
      var a2 = de(o2);
      if (e2._pendingPullIntos.length > 0) {
        var u2 = e2._pendingPullIntos.peek();
        if (pe(u2.buffer)) throw new TypeError("The BYOB request's buffer has been detached and so cannot be filled with an enqueued chunk");
        Ge(e2), u2.buffer = de(u2.buffer), "none" === u2.readerType && Ne(e2, u2);
      }
      if (Z(t2)) if ((function(e3) {
        for (var r3 = e3._controlledReadableByteStream._reader; r3._readRequests.length > 0; ) {
          if (0 === e3._queueTotalSize) return;
          tr(e3, r3._readRequests.shift());
        }
      })(e2), 0 === K(t2)) xe(e2, a2, n2, i2);
      else e2._pendingPullIntos.length > 0 && Ke(e2), J(t2, new Uint8Array(a2, n2, i2), false);
      else if (br(t2)) {
        xe(e2, a2, n2, i2), Me(t2, Xe(e2));
      } else xe(e2, a2, n2, i2);
      Fe(e2);
    }
  }
  function rr(e2, r2) {
    var t2 = e2._controlledReadableByteStream;
    "readable" === t2._state && (Le(e2), We(e2), Ze(e2), ro(t2, r2));
  }
  function tr(e2, r2) {
    var t2 = e2._queue.shift();
    e2._queueTotalSize -= t2.byteLength, Ue(e2);
    var o2 = new Uint8Array(t2.buffer, t2.byteOffset, t2.byteLength);
    r2._chunkSteps(o2);
  }
  function or(e2) {
    if (null === e2._byobRequest && e2._pendingPullIntos.length > 0) {
      var r2 = e2._pendingPullIntos.peek(), t2 = new Uint8Array(r2.buffer, r2.byteOffset + r2.bytesFilled, r2.byteLength - r2.bytesFilled), o2 = Object.create(ke.prototype);
      !(function(e3, r3, t3) {
        e3._associatedReadableByteStreamController = r3, e3._view = t3;
      })(o2, e2, t2), e2._byobRequest = o2;
    }
    return e2._byobRequest;
  }
  function nr(e2) {
    var r2 = e2._controlledReadableByteStream._state;
    return "errored" === r2 ? null : "closed" === r2 ? 0 : e2._strategyHWM - e2._queueTotalSize;
  }
  function ir(e2, r2) {
    var t2 = e2._pendingPullIntos.peek();
    if ("closed" === e2._controlledReadableByteStream._state) {
      if (0 !== r2) throw new TypeError("bytesWritten must be 0 when calling respond() on a closed stream");
    } else {
      if (0 === r2) throw new TypeError("bytesWritten must be greater than 0 when calling respond() on a readable stream");
      if (t2.bytesFilled + r2 > t2.byteLength) throw new RangeError("bytesWritten out of range");
    }
    t2.buffer = de(t2.buffer), Je(e2, r2);
  }
  function ar(e2, r2) {
    var t2 = e2._pendingPullIntos.peek();
    if ("closed" === e2._controlledReadableByteStream._state) {
      if (0 !== r2.byteLength) throw new TypeError("The view's length must be 0 when calling respondWithNewView() on a closed stream");
    } else if (0 === r2.byteLength) throw new TypeError("The view's length must be greater than 0 when calling respondWithNewView() on a readable stream");
    if (t2.byteOffset + t2.bytesFilled !== r2.byteOffset) throw new RangeError("The region specified by view does not match byobRequest");
    if (t2.bufferByteLength !== r2.buffer.byteLength) throw new RangeError("The buffer of view has different capacity than byobRequest");
    if (t2.bytesFilled + r2.byteLength > t2.byteLength) throw new RangeError("The region specified by view is larger than byobRequest");
    var o2 = r2.byteLength;
    t2.buffer = de(r2.buffer), Je(e2, o2);
  }
  function ur(e2, r2, t2, o2, n2, i2, a2) {
    r2._controlledReadableByteStream = e2, r2._pullAgain = false, r2._pulling = false, r2._byobRequest = null, r2._queue = r2._queueTotalSize = void 0, We(r2), r2._closeRequested = false, r2._started = false, r2._strategyHWM = i2, r2._pullAlgorithm = o2, r2._cancelAlgorithm = n2, r2._autoAllocateChunkSize = a2, r2._pendingPullIntos = new w(), e2._readableStreamController = r2, b(f(t2()), function() {
      return r2._started = true, Fe(r2), null;
    }, function(e3) {
      return rr(r2, e3), null;
    });
  }
  function lr(e2) {
    return new TypeError("ReadableStreamBYOBRequest.prototype.".concat(e2, " can only be used on a ReadableStreamBYOBRequest"));
  }
  function sr(e2) {
    return new TypeError("ReadableByteStreamController.prototype.".concat(e2, " can only be used on a ReadableByteStreamController"));
  }
  function cr(e2, r2) {
    if ("byob" !== (e2 = "".concat(e2))) throw new TypeError("".concat(r2, " '").concat(e2, "' is not a valid enumeration value for ReadableStreamReaderMode"));
    return e2;
  }
  function fr(e2) {
    return new hr(e2);
  }
  function dr(e2, r2) {
    e2._reader._readIntoRequests.push(r2);
  }
  function pr(e2) {
    return e2._reader._readIntoRequests.length;
  }
  function br(e2) {
    var r2 = e2._reader;
    return void 0 !== r2 && !!vr(r2);
  }
  Object.defineProperties(Ae.prototype, { close: { enumerable: true }, enqueue: { enumerable: true }, error: { enumerable: true }, byobRequest: { enumerable: true }, desiredSize: { enumerable: true } }), n(Ae.prototype.close, "close"), n(Ae.prototype.enqueue, "enqueue"), n(Ae.prototype.error, "error"), "symbol" == typeof e.toStringTag && Object.defineProperty(Ae.prototype, e.toStringTag, { value: "ReadableByteStreamController", configurable: true });
  var hr = (function() {
    function ReadableStreamBYOBReader(e2) {
      if (x(e2, 1, "ReadableStreamBYOBReader"), U(e2, "First parameter"), Zt(e2)) throw new TypeError("This stream has already been locked for exclusive reading by another reader");
      if (!ze(e2._readableStreamController)) throw new TypeError("Cannot construct a ReadableStreamBYOBReader for a stream not constructed with a byte source");
      O(this, e2), this._readIntoRequests = new w();
    }
    return Object.defineProperty(ReadableStreamBYOBReader.prototype, "closed", { get: function() {
      return vr(this) ? this._closedPromise : d(Sr("closed"));
    }, enumerable: false, configurable: true }), ReadableStreamBYOBReader.prototype.cancel = function(e2) {
      return void 0 === e2 && (e2 = void 0), vr(this) ? void 0 === this._ownerReadableStream ? d(B("cancel")) : W(this, e2) : d(Sr("cancel"));
    }, ReadableStreamBYOBReader.prototype.read = function(e2, r2) {
      if (void 0 === r2 && (r2 = {}), !vr(this)) return d(Sr("read"));
      if (!ArrayBuffer.isView(e2)) return d(new TypeError("view must be an array buffer view"));
      if (0 === e2.byteLength) return d(new TypeError("view must have non-zero byteLength"));
      if (0 === e2.buffer.byteLength) return d(new TypeError("view's buffer must have non-zero byteLength"));
      if (pe(e2.buffer)) return d(new TypeError("view's buffer has been detached"));
      var t2;
      try {
        t2 = (function(e3, r3) {
          var t3;
          return I(e3, r3), { min: V(null !== (t3 = null == e3 ? void 0 : e3.min) && void 0 !== t3 ? t3 : 1, "".concat(r3, " has member 'min' that")) };
        })(r2, "options");
      } catch (e3) {
        return d(e3);
      }
      var o2 = t2.min;
      if (0 === o2) return d(new TypeError("options.min must be greater than 0"));
      if ((function(e3) {
        return je(e3.constructor);
      })(e2)) {
        if (o2 > e2.byteLength) return d(new RangeError("options.min must be less than or equal to view's byteLength"));
      } else if (o2 > e2.length) return d(new RangeError("options.min must be less than or equal to view's length"));
      if (void 0 === this._ownerReadableStream) return d(B("read from"));
      var n2 = (function(e3, r3, t3) {
        var o3 = e3._ownerReadableStream;
        return "errored" === o3._state || (function(e4, r4, t4) {
          var o4 = e4._controlledReadableByteStream, n3 = Be(r4.constructor);
          r4.byteLength;
          var i2 = t4 * n3;
          return !(e4._pendingPullIntos.length > 0) && ("closed" === o4._state || e4._queueTotalSize >= i2);
        })(o3._readableStreamController, r3, t3);
      })(this, e2, o2) ? new mr() : new _r();
      return yr(this, e2, o2, n2), n2._promise;
    }, ReadableStreamBYOBReader.prototype.releaseLock = function() {
      if (!vr(this)) throw Sr("releaseLock");
      void 0 !== this._ownerReadableStream && (function(e2) {
        j(e2);
        var r2 = new TypeError("Reader was released");
        gr(e2, r2);
      })(this);
    }, ReadableStreamBYOBReader;
  })();
  Object.defineProperties(hr.prototype, { cancel: { enumerable: true }, read: { enumerable: true }, releaseLock: { enumerable: true }, closed: { enumerable: true } }), n(hr.prototype.cancel, "cancel"), n(hr.prototype.read, "read"), n(hr.prototype.releaseLock, "releaseLock"), "symbol" == typeof e.toStringTag && Object.defineProperty(hr.prototype, e.toStringTag, { value: "ReadableStreamBYOBReader", configurable: true });
  var _r = (function() {
    function e2() {
      var e3 = this;
      this._promise = c(function(r2, t2) {
        e3._resolvePromise = r2, e3._rejectPromise = t2;
      });
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._resolvePromise({ value: e3, done: false });
    }, e2.prototype._closeSteps = function(e3) {
      this._resolvePromise({ value: e3, done: true });
    }, e2.prototype._errorSteps = function(e3) {
      this._rejectPromise(e3);
    }, e2;
  })(), mr = (function() {
    function e2() {
      this._promise = void 0;
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._promise = s({ value: e3, done: false });
    }, e2.prototype._closeSteps = function(e3) {
      this._promise = s({ value: e3, done: true });
    }, e2.prototype._errorSteps = function(e3) {
      this._promise = d(e3);
    }, e2;
  })();
  function vr(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_readIntoRequests") && e2 instanceof hr);
  }
  function yr(e2, r2, t2, o2) {
    var n2 = e2._ownerReadableStream;
    n2._disturbed = true, "errored" === n2._state ? o2._errorSteps(n2._storedError) : (function(e3, r3, t3, o3) {
      var n3, i2 = e3._controlledReadableByteStream, a2 = r3.constructor, u2 = Be(a2), l2 = r3.byteOffset, s2 = r3.byteLength, c2 = t3 * u2;
      try {
        n3 = de(r3.buffer);
      } catch (p3) {
        return void o3._errorSteps(p3);
      }
      var f2 = { buffer: n3, bufferByteLength: n3.byteLength, byteOffset: l2, byteLength: s2, bytesFilled: 0, minimumFill: c2, elementSize: u2, viewConstructor: a2, readerType: "byob" };
      if (e3._pendingPullIntos.length > 0) return e3._pendingPullIntos.push(f2), void dr(i2, o3);
      if ("closed" !== i2._state) {
        if (e3._queueTotalSize > 0) {
          if (He(e3, f2)) {
            var d2 = Ye(f2);
            return Ue(e3), void o3._chunkSteps(d2);
          }
          if (e3._closeRequested) {
            var p2 = new TypeError("Insufficient bytes to fill elements in the given buffer");
            return rr(e3, p2), void o3._errorSteps(p2);
          }
        }
        e3._pendingPullIntos.push(f2), dr(i2, o3), Fe(e3);
      } else {
        var b2 = new a2(f2.buffer, f2.byteOffset, 0);
        o3._closeSteps(b2);
      }
    })(n2._readableStreamController, r2, t2, o2);
  }
  function gr(e2, r2) {
    var t2 = e2._readIntoRequests;
    e2._readIntoRequests = new w(), t2.forEach(function(e3) {
      e3._errorSteps(r2);
    });
  }
  function Sr(e2) {
    return new TypeError("ReadableStreamBYOBReader.prototype.".concat(e2, " can only be used on a ReadableStreamBYOBReader"));
  }
  function wr(e2, r2) {
    var t2 = e2.highWaterMark;
    if (void 0 === t2) return r2;
    if (Ce(t2) || t2 < 0) throw new RangeError("Invalid highWaterMark");
    return t2;
  }
  function Rr(e2) {
    var r2 = e2.size;
    return r2 || function() {
      return 1;
    };
  }
  function Tr(e2, r2) {
    I(e2, r2);
    var t2 = null == e2 ? void 0 : e2.highWaterMark, o2 = null == e2 ? void 0 : e2.size;
    return { highWaterMark: void 0 === t2 ? void 0 : N(t2), size: void 0 === o2 ? void 0 : Pr(o2, "".concat(r2, " has member 'size' that")) };
  }
  function Pr(e2, r2) {
    return M(e2, r2), function(r3) {
      return N(e2(r3));
    };
  }
  function Cr(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return S(e2, r2, [t3]);
    };
  }
  function qr(e2, r2, t2) {
    return M(e2, t2), function() {
      return S(e2, r2, []);
    };
  }
  function Er(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return g(e2, r2, [t3]);
    };
  }
  function Or(e2, r2, t2) {
    return M(e2, t2), function(t3, o2) {
      return S(e2, r2, [t3, o2]);
    };
  }
  function Wr(e2, r2) {
    if (!Ar(e2)) throw new TypeError("".concat(r2, " is not a WritableStream."));
  }
  var jr = (function() {
    function WritableStream(e2, r2) {
      void 0 === e2 && (e2 = {}), void 0 === r2 && (r2 = {}), void 0 === e2 ? e2 = null : Y(e2, "First parameter");
      var t2 = Tr(r2, "Second parameter"), o2 = (function(e3, r3) {
        I(e3, r3);
        var t3 = null == e3 ? void 0 : e3.abort, o3 = null == e3 ? void 0 : e3.close, n3 = null == e3 ? void 0 : e3.start, i2 = null == e3 ? void 0 : e3.type, a2 = null == e3 ? void 0 : e3.write;
        return { abort: void 0 === t3 ? void 0 : Cr(t3, e3, "".concat(r3, " has member 'abort' that")), close: void 0 === o3 ? void 0 : qr(o3, e3, "".concat(r3, " has member 'close' that")), start: void 0 === n3 ? void 0 : Er(n3, e3, "".concat(r3, " has member 'start' that")), write: void 0 === a2 ? void 0 : Or(a2, e3, "".concat(r3, " has member 'write' that")), type: i2 };
      })(e2, "First parameter");
      if (kr(this), void 0 !== o2.type) throw new RangeError("Invalid type is specified");
      var n2 = Rr(t2);
      !(function(e3, r3, t3, o3) {
        var n3, i2, a2, u2, l2 = Object.create(Zr.prototype);
        n3 = void 0 !== r3.start ? function() {
          return r3.start(l2);
        } : function() {
        };
        i2 = void 0 !== r3.write ? function(e4) {
          return r3.write(e4, l2);
        } : function() {
          return f(void 0);
        };
        a2 = void 0 !== r3.close ? function() {
          return r3.close();
        } : function() {
          return f(void 0);
        };
        u2 = void 0 !== r3.abort ? function(e4) {
          return r3.abort(e4);
        } : function() {
          return f(void 0);
        };
        et(e3, l2, n3, i2, a2, u2, t3, o3);
      })(this, o2, wr(t2, 1), n2);
    }
    return Object.defineProperty(WritableStream.prototype, "locked", { get: function() {
      if (!Ar(this)) throw ut("locked");
      return zr(this);
    }, enumerable: false, configurable: true }), WritableStream.prototype.abort = function(e2) {
      return void 0 === e2 && (e2 = void 0), Ar(this) ? zr(this) ? d(new TypeError("Cannot abort a stream that already has a writer")) : Dr(this, e2) : d(ut("abort"));
    }, WritableStream.prototype.close = function() {
      return Ar(this) ? zr(this) ? d(new TypeError("Cannot close a stream that already has a writer")) : Yr(this) ? d(new TypeError("Cannot close an already-closing stream")) : Fr(this) : d(ut("close"));
    }, WritableStream.prototype.getWriter = function() {
      if (!Ar(this)) throw ut("getWriter");
      return Br(this);
    }, WritableStream;
  })();
  function Br(e2) {
    return new Nr(e2);
  }
  function kr(e2) {
    e2._state = "writable", e2._storedError = void 0, e2._writer = void 0, e2._writableStreamController = void 0, e2._writeRequests = new w(), e2._inFlightWriteRequest = void 0, e2._closeRequest = void 0, e2._inFlightCloseRequest = void 0, e2._pendingAbortRequest = void 0, e2._backpressure = false;
  }
  function Ar(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_writableStreamController") && e2 instanceof jr);
  }
  function zr(e2) {
    return void 0 !== e2._writer;
  }
  function Dr(e2, r2) {
    var t2;
    if ("closed" === e2._state || "errored" === e2._state) return f(void 0);
    e2._writableStreamController._abortReason = r2, null === (t2 = e2._writableStreamController._abortController) || void 0 === t2 || t2.abort(r2);
    var o2 = e2._state;
    if ("closed" === o2 || "errored" === o2) return f(void 0);
    if (void 0 !== e2._pendingAbortRequest) return e2._pendingAbortRequest._promise;
    var n2 = false;
    "erroring" === o2 && (n2 = true, r2 = void 0);
    var i2 = c(function(t3, o3) {
      e2._pendingAbortRequest = { _promise: void 0, _resolve: t3, _reject: o3, _reason: r2, _wasAlreadyErroring: n2 };
    });
    return e2._pendingAbortRequest._promise = i2, n2 || Ir(e2, r2), i2;
  }
  function Fr(e2) {
    var r2 = e2._state;
    if ("closed" === r2 || "errored" === r2) return d(new TypeError("The stream (in ".concat(r2, " state) is not in the writable state and cannot be closed")));
    var t2, o2 = c(function(r3, t3) {
      var o3 = { _resolve: r3, _reject: t3 };
      e2._closeRequest = o3;
    }), n2 = e2._writer;
    return void 0 !== n2 && e2._backpressure && "writable" === r2 && yt(n2), Oe(t2 = e2._writableStreamController, Kr, 0), ot(t2), o2;
  }
  function Lr(e2, r2) {
    "writable" !== e2._state ? Mr(e2) : Ir(e2, r2);
  }
  function Ir(e2, r2) {
    var t2 = e2._writableStreamController;
    e2._state = "erroring", e2._storedError = r2;
    var o2 = e2._writer;
    void 0 !== o2 && Gr(o2, r2), !(function(e3) {
      if (void 0 === e3._inFlightWriteRequest && void 0 === e3._inFlightCloseRequest) return false;
      return true;
    })(e2) && t2._started && Mr(e2);
  }
  function Mr(e2) {
    e2._state = "errored", e2._writableStreamController[T]();
    var r2 = e2._storedError;
    if (e2._writeRequests.forEach(function(e3) {
      e3._reject(r2);
    }), e2._writeRequests = new w(), void 0 !== e2._pendingAbortRequest) {
      var t2 = e2._pendingAbortRequest;
      if (e2._pendingAbortRequest = void 0, t2._wasAlreadyErroring) return t2._reject(r2), void xr(e2);
      b(e2._writableStreamController[R](t2._reason), function() {
        return t2._resolve(), xr(e2), null;
      }, function(r3) {
        return t2._reject(r3), xr(e2), null;
      });
    } else xr(e2);
  }
  function Yr(e2) {
    return void 0 !== e2._closeRequest || void 0 !== e2._inFlightCloseRequest;
  }
  function xr(e2) {
    void 0 !== e2._closeRequest && (e2._closeRequest._reject(e2._storedError), e2._closeRequest = void 0);
    var r2 = e2._writer;
    void 0 !== r2 && pt(r2, e2._storedError);
  }
  function Qr(e2, r2) {
    var t2 = e2._writer;
    void 0 !== t2 && r2 !== e2._backpressure && (r2 ? (function(e3) {
      ht(e3);
    })(t2) : yt(t2)), e2._backpressure = r2;
  }
  Object.defineProperties(jr.prototype, { abort: { enumerable: true }, close: { enumerable: true }, getWriter: { enumerable: true }, locked: { enumerable: true } }), n(jr.prototype.abort, "abort"), n(jr.prototype.close, "close"), n(jr.prototype.getWriter, "getWriter"), "symbol" == typeof e.toStringTag && Object.defineProperty(jr.prototype, e.toStringTag, { value: "WritableStream", configurable: true });
  var Nr = (function() {
    function WritableStreamDefaultWriter(e2) {
      if (x(e2, 1, "WritableStreamDefaultWriter"), Wr(e2, "First parameter"), zr(e2)) throw new TypeError("This stream has already been locked for exclusive writing by another writer");
      this._ownerWritableStream = e2, e2._writer = this;
      var r2, t2 = e2._state;
      if ("writable" === t2) !Yr(e2) && e2._backpressure ? ht(this) : mt(this), ft(this);
      else if ("erroring" === t2) _t(this, e2._storedError), ft(this);
      else if ("closed" === t2) mt(this), ft(r2 = this), bt(r2);
      else {
        var o2 = e2._storedError;
        _t(this, o2), dt(this, o2);
      }
    }
    return Object.defineProperty(WritableStreamDefaultWriter.prototype, "closed", { get: function() {
      return Hr(this) ? this._closedPromise : d(st("closed"));
    }, enumerable: false, configurable: true }), Object.defineProperty(WritableStreamDefaultWriter.prototype, "desiredSize", { get: function() {
      if (!Hr(this)) throw st("desiredSize");
      if (void 0 === this._ownerWritableStream) throw ct("desiredSize");
      return (function(e2) {
        var r2 = e2._ownerWritableStream, t2 = r2._state;
        if ("errored" === t2 || "erroring" === t2) return null;
        if ("closed" === t2) return 0;
        return tt(r2._writableStreamController);
      })(this);
    }, enumerable: false, configurable: true }), Object.defineProperty(WritableStreamDefaultWriter.prototype, "ready", { get: function() {
      return Hr(this) ? this._readyPromise : d(st("ready"));
    }, enumerable: false, configurable: true }), WritableStreamDefaultWriter.prototype.abort = function(e2) {
      return void 0 === e2 && (e2 = void 0), Hr(this) ? void 0 === this._ownerWritableStream ? d(ct("abort")) : (function(e3, r2) {
        return Dr(e3._ownerWritableStream, r2);
      })(this, e2) : d(st("abort"));
    }, WritableStreamDefaultWriter.prototype.close = function() {
      if (!Hr(this)) return d(st("close"));
      var e2 = this._ownerWritableStream;
      return void 0 === e2 ? d(ct("close")) : Yr(e2) ? d(new TypeError("Cannot close an already-closing stream")) : Vr(this);
    }, WritableStreamDefaultWriter.prototype.releaseLock = function() {
      if (!Hr(this)) throw st("releaseLock");
      void 0 !== this._ownerWritableStream && Xr(this);
    }, WritableStreamDefaultWriter.prototype.write = function(e2) {
      return void 0 === e2 && (e2 = void 0), Hr(this) ? void 0 === this._ownerWritableStream ? d(ct("write to")) : Jr(this, e2) : d(st("write"));
    }, WritableStreamDefaultWriter;
  })();
  function Hr(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_ownerWritableStream") && e2 instanceof Nr);
  }
  function Vr(e2) {
    return Fr(e2._ownerWritableStream);
  }
  function Ur(e2, r2) {
    "pending" === e2._closedPromiseState ? pt(e2, r2) : (function(e3, r3) {
      dt(e3, r3);
    })(e2, r2);
  }
  function Gr(e2, r2) {
    "pending" === e2._readyPromiseState ? vt(e2, r2) : (function(e3, r3) {
      _t(e3, r3);
    })(e2, r2);
  }
  function Xr(e2) {
    var r2 = e2._ownerWritableStream, t2 = new TypeError("Writer was released and can no longer be used to monitor the stream's closedness");
    Gr(e2, t2), Ur(e2, t2), r2._writer = void 0, e2._ownerWritableStream = void 0;
  }
  function Jr(e2, r2) {
    var t2 = e2._ownerWritableStream, o2 = t2._writableStreamController, n2 = (function(e3, r3) {
      if (void 0 === e3._strategySizeAlgorithm) return 1;
      try {
        return e3._strategySizeAlgorithm(r3);
      } catch (r4) {
        return nt(e3, r4), 1;
      }
    })(o2, r2);
    if (t2 !== e2._ownerWritableStream) return d(ct("write to"));
    var i2 = t2._state;
    if ("errored" === i2) return d(t2._storedError);
    if (Yr(t2) || "closed" === i2) return d(new TypeError("The stream is closing or closed and cannot be written to"));
    if ("erroring" === i2) return d(t2._storedError);
    var a2 = (function(e3) {
      return c(function(r3, t3) {
        var o3 = { _resolve: r3, _reject: t3 };
        e3._writeRequests.push(o3);
      });
    })(t2);
    return (function(e3, r3, t3) {
      try {
        Oe(e3, r3, t3);
      } catch (r4) {
        return void nt(e3, r4);
      }
      var o3 = e3._controlledWritableStream;
      if (!Yr(o3) && "writable" === o3._state) {
        Qr(o3, it(e3));
      }
      ot(e3);
    })(o2, r2, n2), a2;
  }
  Object.defineProperties(Nr.prototype, { abort: { enumerable: true }, close: { enumerable: true }, releaseLock: { enumerable: true }, write: { enumerable: true }, closed: { enumerable: true }, desiredSize: { enumerable: true }, ready: { enumerable: true } }), n(Nr.prototype.abort, "abort"), n(Nr.prototype.close, "close"), n(Nr.prototype.releaseLock, "releaseLock"), n(Nr.prototype.write, "write"), "symbol" == typeof e.toStringTag && Object.defineProperty(Nr.prototype, e.toStringTag, { value: "WritableStreamDefaultWriter", configurable: true });
  var Kr = {}, Zr = (function() {
    function WritableStreamDefaultController() {
      throw new TypeError("Illegal constructor");
    }
    return Object.defineProperty(WritableStreamDefaultController.prototype, "abortReason", { get: function() {
      if (!$r(this)) throw lt("abortReason");
      return this._abortReason;
    }, enumerable: false, configurable: true }), Object.defineProperty(WritableStreamDefaultController.prototype, "signal", { get: function() {
      if (!$r(this)) throw lt("signal");
      if (void 0 === this._abortController) throw new TypeError("WritableStreamDefaultController.prototype.signal is not supported");
      return this._abortController.signal;
    }, enumerable: false, configurable: true }), WritableStreamDefaultController.prototype.error = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !$r(this)) throw lt("error");
      "writable" === this._controlledWritableStream._state && at(this, e2);
    }, WritableStreamDefaultController.prototype[R] = function(e2) {
      var r2 = this._abortAlgorithm(e2);
      return rt(this), r2;
    }, WritableStreamDefaultController.prototype[T] = function() {
      We(this);
    }, WritableStreamDefaultController;
  })();
  function $r(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_controlledWritableStream") && e2 instanceof Zr);
  }
  function et(e2, r2, t2, o2, n2, i2, a2, u2) {
    r2._controlledWritableStream = e2, e2._writableStreamController = r2, r2._queue = void 0, r2._queueTotalSize = void 0, We(r2), r2._abortReason = void 0, r2._abortController = (function() {
      if ("function" == typeof AbortController) return new AbortController();
    })(), r2._started = false, r2._strategySizeAlgorithm = u2, r2._strategyHWM = a2, r2._writeAlgorithm = o2, r2._closeAlgorithm = n2, r2._abortAlgorithm = i2;
    var l2 = it(r2);
    Qr(e2, l2), b(f(t2()), function() {
      return r2._started = true, ot(r2), null;
    }, function(t3) {
      return r2._started = true, Lr(e2, t3), null;
    });
  }
  function rt(e2) {
    e2._writeAlgorithm = void 0, e2._closeAlgorithm = void 0, e2._abortAlgorithm = void 0, e2._strategySizeAlgorithm = void 0;
  }
  function tt(e2) {
    return e2._strategyHWM - e2._queueTotalSize;
  }
  function ot(e2) {
    var r2 = e2._controlledWritableStream;
    if (e2._started && void 0 === r2._inFlightWriteRequest) if ("erroring" !== r2._state) {
      if (0 !== e2._queue.length) {
        var t2 = e2._queue.peek().value;
        t2 === Kr ? (function(e3) {
          var r3 = e3._controlledWritableStream;
          (function(e4) {
            e4._inFlightCloseRequest = e4._closeRequest, e4._closeRequest = void 0;
          })(r3), Ee(e3);
          var t3 = e3._closeAlgorithm();
          rt(e3), b(t3, function() {
            return (function(e4) {
              e4._inFlightCloseRequest._resolve(void 0), e4._inFlightCloseRequest = void 0, "erroring" === e4._state && (e4._storedError = void 0, void 0 !== e4._pendingAbortRequest && (e4._pendingAbortRequest._resolve(), e4._pendingAbortRequest = void 0)), e4._state = "closed";
              var r4 = e4._writer;
              void 0 !== r4 && bt(r4);
            })(r3), null;
          }, function(e4) {
            return (function(e5, r4) {
              e5._inFlightCloseRequest._reject(r4), e5._inFlightCloseRequest = void 0, void 0 !== e5._pendingAbortRequest && (e5._pendingAbortRequest._reject(r4), e5._pendingAbortRequest = void 0), Lr(e5, r4);
            })(r3, e4), null;
          });
        })(e2) : (function(e3, r3) {
          var t3 = e3._controlledWritableStream;
          !(function(e4) {
            e4._inFlightWriteRequest = e4._writeRequests.shift();
          })(t3);
          var o2 = e3._writeAlgorithm(r3);
          b(o2, function() {
            !(function(e4) {
              e4._inFlightWriteRequest._resolve(void 0), e4._inFlightWriteRequest = void 0;
            })(t3);
            var r4 = t3._state;
            if (Ee(e3), !Yr(t3) && "writable" === r4) {
              var o3 = it(e3);
              Qr(t3, o3);
            }
            return ot(e3), null;
          }, function(r4) {
            return "writable" === t3._state && rt(e3), (function(e4, r5) {
              e4._inFlightWriteRequest._reject(r5), e4._inFlightWriteRequest = void 0, Lr(e4, r5);
            })(t3, r4), null;
          });
        })(e2, t2);
      }
    } else Mr(r2);
  }
  function nt(e2, r2) {
    "writable" === e2._controlledWritableStream._state && at(e2, r2);
  }
  function it(e2) {
    return tt(e2) <= 0;
  }
  function at(e2, r2) {
    var t2 = e2._controlledWritableStream;
    rt(e2), Ir(t2, r2);
  }
  function ut(e2) {
    return new TypeError("WritableStream.prototype.".concat(e2, " can only be used on a WritableStream"));
  }
  function lt(e2) {
    return new TypeError("WritableStreamDefaultController.prototype.".concat(e2, " can only be used on a WritableStreamDefaultController"));
  }
  function st(e2) {
    return new TypeError("WritableStreamDefaultWriter.prototype.".concat(e2, " can only be used on a WritableStreamDefaultWriter"));
  }
  function ct(e2) {
    return new TypeError("Cannot " + e2 + " a stream using a released writer");
  }
  function ft(e2) {
    e2._closedPromise = c(function(r2, t2) {
      e2._closedPromise_resolve = r2, e2._closedPromise_reject = t2, e2._closedPromiseState = "pending";
    });
  }
  function dt(e2, r2) {
    ft(e2), pt(e2, r2);
  }
  function pt(e2, r2) {
    void 0 !== e2._closedPromise_reject && (v(e2._closedPromise), e2._closedPromise_reject(r2), e2._closedPromise_resolve = void 0, e2._closedPromise_reject = void 0, e2._closedPromiseState = "rejected");
  }
  function bt(e2) {
    void 0 !== e2._closedPromise_resolve && (e2._closedPromise_resolve(void 0), e2._closedPromise_resolve = void 0, e2._closedPromise_reject = void 0, e2._closedPromiseState = "resolved");
  }
  function ht(e2) {
    e2._readyPromise = c(function(r2, t2) {
      e2._readyPromise_resolve = r2, e2._readyPromise_reject = t2;
    }), e2._readyPromiseState = "pending";
  }
  function _t(e2, r2) {
    ht(e2), vt(e2, r2);
  }
  function mt(e2) {
    ht(e2), yt(e2);
  }
  function vt(e2, r2) {
    void 0 !== e2._readyPromise_reject && (v(e2._readyPromise), e2._readyPromise_reject(r2), e2._readyPromise_resolve = void 0, e2._readyPromise_reject = void 0, e2._readyPromiseState = "rejected");
  }
  function yt(e2) {
    void 0 !== e2._readyPromise_resolve && (e2._readyPromise_resolve(void 0), e2._readyPromise_resolve = void 0, e2._readyPromise_reject = void 0, e2._readyPromiseState = "fulfilled");
  }
  Object.defineProperties(Zr.prototype, { abortReason: { enumerable: true }, signal: { enumerable: true }, error: { enumerable: true } }), "symbol" == typeof e.toStringTag && Object.defineProperty(Zr.prototype, e.toStringTag, { value: "WritableStreamDefaultController", configurable: true });
  var gt = "undefined" != typeof globalThis ? globalThis : "undefined" != typeof self ? self : "undefined" != typeof global ? global : void 0;
  var St, wt = ((function(e2) {
    if ("function" != typeof e2 && "object" != typeof e2) return false;
    if ("DOMException" !== e2.name) return false;
    try {
      return new e2(), true;
    } catch (e3) {
      return false;
    }
  })(St = null == gt ? void 0 : gt.DOMException) ? St : void 0) || (function() {
    var e2 = function(e3, r2) {
      this.message = e3 || "", this.name = r2 || "Error", Error.captureStackTrace && Error.captureStackTrace(this, this.constructor);
    };
    return n(e2, "DOMException"), e2.prototype = Object.create(Error.prototype), Object.defineProperty(e2.prototype, "constructor", { value: e2, writable: true, configurable: true }), e2;
  })();
  function Rt(e2, r2, t2, o2, n2, i2) {
    var a2 = G(e2), u2 = Br(r2);
    e2._disturbed = true;
    var l2 = new Tt(u2), s2 = new Ct(l2);
    return c(function(_2, m2) {
      var y2, g2, S2, w2;
      if (void 0 !== i2) {
        if (y2 = function() {
          var t3 = void 0 !== i2.reason ? i2.reason : new wt("Aborted", "AbortError"), a3 = [];
          o2 || a3.push(function() {
            return "writable" === r2._state ? Dr(r2, t3) : f(void 0);
          }), n2 || a3.push(function() {
            return "readable" === e2._state ? $t(e2, t3) : f(void 0);
          }), P2(function() {
            return Promise.all(a3.map(function(e3) {
              return e3();
            }));
          }, true, t3);
        }, i2.aborted) return void y2();
        i2.addEventListener("abort", y2);
      }
      function R2() {
        for (; !l2._shuttingDown && !r2._backpressure && "writable" === r2._state && !Yr(r2) && "readable" === e2._state && ue(a2); ) ae(a2, s2);
        if (l2._shuttingDown) return f(true);
        if (r2._backpressure) return p(u2._readyPromise, R2);
        var t3 = new Pt(l2);
        return ae(a2, t3), t3._promise;
      }
      if (qt(e2, a2._closedPromise, function(e3) {
        return o2 ? C2(true, e3) : P2(function() {
          return Dr(r2, e3);
        }, true, e3), null;
      }), qt(r2, u2._closedPromise, function(r3) {
        return n2 ? C2(true, r3) : P2(function() {
          return $t(e2, r3);
        }, true, r3), null;
      }), g2 = e2, S2 = a2._closedPromise, w2 = function() {
        return t2 ? C2() : P2(function() {
          return (function(e3) {
            var r3 = e3._ownerWritableStream, t3 = r3._state;
            return Yr(r3) || "closed" === t3 ? f(void 0) : "errored" === t3 ? d(r3._storedError) : Vr(e3);
          })(u2);
        }), null;
      }, "closed" === g2._state ? w2() : h(S2, w2), Yr(r2) || "closed" === r2._state) {
        var T2 = new TypeError("the destination writable stream closed before all data could be piped to it");
        n2 ? C2(true, T2) : P2(function() {
          return $t(e2, T2);
        }, true, T2);
      }
      function P2(e3, t3, o3) {
        function n3() {
          return b(e3(), function() {
            return q2(t3, o3);
          }, function(e4) {
            return q2(true, e4);
          }), null;
        }
        l2._shuttingDown || (l2._shuttingDown = true, "writable" !== r2._state || Yr(r2) ? n3() : h(l2._waitForWritesToFinish(), n3));
      }
      function C2(e3, t3) {
        l2._shuttingDown || (l2._shuttingDown = true, "writable" !== r2._state || Yr(r2) ? q2(e3, t3) : h(l2._waitForWritesToFinish(), function() {
          return q2(e3, t3);
        }));
      }
      function q2(e3, r3) {
        return Xr(u2), j(a2), void 0 !== i2 && i2.removeEventListener("abort", y2), e3 ? m2(r3) : _2(void 0), null;
      }
      v(c(function(e3, r3) {
        !(function t3(o3) {
          o3 ? e3() : p(R2(), t3, r3);
        })(false);
      }));
    });
  }
  var Tt = (function() {
    function e2(e3) {
      this._writer = e3, this._shuttingDown = false, this._currentWrite = f(void 0);
    }
    return e2.prototype._waitForWritesToFinish = function() {
      var e3 = this, r2 = this._currentWrite;
      return p(this._currentWrite, function() {
        return r2 !== e3._currentWrite ? e3._waitForWritesToFinish() : void 0;
      });
    }, e2;
  })(), Pt = (function() {
    function e2(e3) {
      var r2 = this;
      this._state = e3, this._promise = c(function(e4, t2) {
        r2._resolvePromise = e4, r2._rejectPromise = t2;
      });
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._state._currentWrite = p(Jr(this._state._writer, e3), void 0, r), this._resolvePromise(false);
    }, e2.prototype._closeSteps = function() {
      this._resolvePromise(true);
    }, e2.prototype._errorSteps = function(e3) {
      this._rejectPromise(e3);
    }, e2;
  })(), Ct = (function() {
    function e2(e3) {
      this._state = e3;
    }
    return e2.prototype._chunkSteps = function(e3) {
      this._state._currentWrite = p(Jr(this._state._writer, e3), void 0, r);
    }, e2.prototype._closeSteps = function() {
    }, e2.prototype._errorSteps = function(e3) {
    }, e2;
  })();
  function qt(e2, r2, t2) {
    "errored" === e2._state ? t2(e2._storedError) : _(r2, t2);
  }
  var Et = (function() {
    function ReadableStreamDefaultController() {
      throw new TypeError("Illegal constructor");
    }
    return Object.defineProperty(ReadableStreamDefaultController.prototype, "desiredSize", { get: function() {
      if (!Ot(this)) throw It("desiredSize");
      return Dt(this);
    }, enumerable: false, configurable: true }), ReadableStreamDefaultController.prototype.close = function() {
      if (!Ot(this)) throw It("close");
      if (!Ft(this)) throw new TypeError("The stream is not in a state that permits close");
      kt(this);
    }, ReadableStreamDefaultController.prototype.enqueue = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !Ot(this)) throw It("enqueue");
      if (!Ft(this)) throw new TypeError("The stream is not in a state that permits enqueue");
      return At(this, e2);
    }, ReadableStreamDefaultController.prototype.error = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !Ot(this)) throw It("error");
      zt(this, e2);
    }, ReadableStreamDefaultController.prototype[P] = function(e2) {
      We(this);
      var r2 = this._cancelAlgorithm(e2);
      return Bt(this), r2;
    }, ReadableStreamDefaultController.prototype[C] = function(e2) {
      var r2 = this._controlledReadableStream;
      if (this._queue.length > 0) {
        var t2 = Ee(this);
        this._closeRequested && 0 === this._queue.length ? (Bt(this), eo(r2)) : Wt(this), e2._chunkSteps(t2);
      } else X(r2, e2), Wt(this);
    }, ReadableStreamDefaultController.prototype[q] = function() {
      return this._queue.length > 0;
    }, ReadableStreamDefaultController.prototype[E] = function() {
    }, ReadableStreamDefaultController;
  })();
  function Ot(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_controlledReadableStream") && e2 instanceof Et);
  }
  function Wt(e2) {
    jt(e2) && (e2._pulling ? e2._pullAgain = true : (e2._pulling = true, b(e2._pullAlgorithm(), function() {
      return e2._pulling = false, e2._pullAgain && (e2._pullAgain = false, Wt(e2)), null;
    }, function(r2) {
      return zt(e2, r2), null;
    })));
  }
  function jt(e2) {
    var r2 = e2._controlledReadableStream;
    return !!Ft(e2) && (!!e2._started && (!!(Zt(r2) && K(r2) > 0) || Dt(e2) > 0));
  }
  function Bt(e2) {
    e2._pullAlgorithm = void 0, e2._cancelAlgorithm = void 0, e2._strategySizeAlgorithm = void 0;
  }
  function kt(e2) {
    if (Ft(e2)) {
      var r2 = e2._controlledReadableStream;
      e2._closeRequested = true, 0 === e2._queue.length && (Bt(e2), eo(r2));
    }
  }
  function At(e2, r2) {
    if (Ft(e2)) {
      var t2 = e2._controlledReadableStream;
      if (Zt(t2) && K(t2) > 0) J(t2, r2, false);
      else {
        var o2 = void 0;
        try {
          o2 = e2._strategySizeAlgorithm(r2);
        } catch (r3) {
          throw zt(e2, r3), r3;
        }
        try {
          Oe(e2, r2, o2);
        } catch (r3) {
          throw zt(e2, r3), r3;
        }
      }
      Wt(e2);
    }
  }
  function zt(e2, r2) {
    var t2 = e2._controlledReadableStream;
    "readable" === t2._state && (We(e2), Bt(e2), ro(t2, r2));
  }
  function Dt(e2) {
    var r2 = e2._controlledReadableStream._state;
    return "errored" === r2 ? null : "closed" === r2 ? 0 : e2._strategyHWM - e2._queueTotalSize;
  }
  function Ft(e2) {
    var r2 = e2._controlledReadableStream._state;
    return !e2._closeRequested && "readable" === r2;
  }
  function Lt(e2, r2, t2, o2, n2, i2, a2) {
    r2._controlledReadableStream = e2, r2._queue = void 0, r2._queueTotalSize = void 0, We(r2), r2._started = false, r2._closeRequested = false, r2._pullAgain = false, r2._pulling = false, r2._strategySizeAlgorithm = a2, r2._strategyHWM = i2, r2._pullAlgorithm = o2, r2._cancelAlgorithm = n2, e2._readableStreamController = r2, b(f(t2()), function() {
      return r2._started = true, Wt(r2), null;
    }, function(e3) {
      return zt(r2, e3), null;
    });
  }
  function It(e2) {
    return new TypeError("ReadableStreamDefaultController.prototype.".concat(e2, " can only be used on a ReadableStreamDefaultController"));
  }
  function Mt(e2, r2) {
    return ze(e2._readableStreamController) ? (function(e3) {
      var r3, t2, o2, n2, i2, a2 = G(e3), u2 = false, l2 = false, s2 = false, d2 = false, p2 = false, b2 = c(function(e4) {
        i2 = e4;
      });
      function h2(e4) {
        _(e4._closedPromise, function(r4) {
          return e4 !== a2 || (rr(o2._readableStreamController, r4), rr(n2._readableStreamController, r4), d2 && p2 || i2(void 0)), null;
        });
      }
      function m2() {
        vr(a2) && (j(a2), h2(a2 = G(e3))), ae(a2, { _chunkSteps: function(r4) {
          y(function() {
            l2 = false, s2 = false;
            var t3 = r4, a3 = r4;
            if (!d2 && !p2) try {
              a3 = qe(r4);
            } catch (r5) {
              return rr(o2._readableStreamController, r5), rr(n2._readableStreamController, r5), void i2($t(e3, r5));
            }
            d2 || er(o2._readableStreamController, t3), p2 || er(n2._readableStreamController, a3), u2 = false, l2 ? g2() : s2 && S2();
          });
        }, _closeSteps: function() {
          u2 = false, d2 || $e(o2._readableStreamController), p2 || $e(n2._readableStreamController), o2._readableStreamController._pendingPullIntos.length > 0 && ir(o2._readableStreamController, 0), n2._readableStreamController._pendingPullIntos.length > 0 && ir(n2._readableStreamController, 0), d2 && p2 || i2(void 0);
        }, _errorSteps: function() {
          u2 = false;
        } });
      }
      function v2(r4, t3) {
        ie(a2) && (j(a2), h2(a2 = fr(e3)));
        var c2 = t3 ? n2 : o2, f2 = t3 ? o2 : n2;
        yr(a2, r4, 1, { _chunkSteps: function(r5) {
          y(function() {
            l2 = false, s2 = false;
            var o3 = t3 ? p2 : d2;
            if (t3 ? d2 : p2) o3 || ar(c2._readableStreamController, r5);
            else {
              var n3 = void 0;
              try {
                n3 = qe(r5);
              } catch (r6) {
                return rr(c2._readableStreamController, r6), rr(f2._readableStreamController, r6), void i2($t(e3, r6));
              }
              o3 || ar(c2._readableStreamController, r5), er(f2._readableStreamController, n3);
            }
            u2 = false, l2 ? g2() : s2 && S2();
          });
        }, _closeSteps: function(e4) {
          u2 = false;
          var r5 = t3 ? p2 : d2, o3 = t3 ? d2 : p2;
          r5 || $e(c2._readableStreamController), o3 || $e(f2._readableStreamController), void 0 !== e4 && (r5 || ar(c2._readableStreamController, e4), !o3 && f2._readableStreamController._pendingPullIntos.length > 0 && ir(f2._readableStreamController, 0)), r5 && o3 || i2(void 0);
        }, _errorSteps: function() {
          u2 = false;
        } });
      }
      function g2() {
        if (u2) return l2 = true, f(void 0);
        u2 = true;
        var e4 = or(o2._readableStreamController);
        return null === e4 ? m2() : v2(e4._view, false), f(void 0);
      }
      function S2() {
        if (u2) return s2 = true, f(void 0);
        u2 = true;
        var e4 = or(n2._readableStreamController);
        return null === e4 ? m2() : v2(e4._view, true), f(void 0);
      }
      function w2(o3) {
        if (d2 = true, r3 = o3, p2) {
          var n3 = ce([r3, t2]), a3 = $t(e3, n3);
          i2(a3);
        }
        return b2;
      }
      function R2(o3) {
        if (p2 = true, t2 = o3, d2) {
          var n3 = ce([r3, t2]), a3 = $t(e3, n3);
          i2(a3);
        }
        return b2;
      }
      function T2() {
      }
      return o2 = Xt(T2, g2, w2), n2 = Xt(T2, S2, R2), h2(a2), [o2, n2];
    })(e2) : (function(e3) {
      var r3, t2, o2, n2, i2, a2 = G(e3), u2 = false, l2 = false, s2 = false, d2 = false, p2 = c(function(e4) {
        i2 = e4;
      });
      function b2() {
        return u2 ? (l2 = true, f(void 0)) : (u2 = true, ae(a2, { _chunkSteps: function(e4) {
          y(function() {
            l2 = false;
            var r4 = e4, t3 = e4;
            s2 || At(o2._readableStreamController, r4), d2 || At(n2._readableStreamController, t3), u2 = false, l2 && b2();
          });
        }, _closeSteps: function() {
          u2 = false, s2 || kt(o2._readableStreamController), d2 || kt(n2._readableStreamController), s2 && d2 || i2(void 0);
        }, _errorSteps: function() {
          u2 = false;
        } }), f(void 0));
      }
      function h2(o3) {
        if (s2 = true, r3 = o3, d2) {
          var n3 = ce([r3, t2]), a3 = $t(e3, n3);
          i2(a3);
        }
        return p2;
      }
      function m2(o3) {
        if (d2 = true, t2 = o3, s2) {
          var n3 = ce([r3, t2]), a3 = $t(e3, n3);
          i2(a3);
        }
        return p2;
      }
      function v2() {
      }
      return o2 = Gt(v2, b2, h2), n2 = Gt(v2, b2, m2), _(a2._closedPromise, function(e4) {
        return zt(o2._readableStreamController, e4), zt(n2._readableStreamController, e4), s2 && d2 || i2(void 0), null;
      }), [o2, n2];
    })(e2);
  }
  function Yt(e2) {
    return t(o2 = e2) && void 0 !== o2.getReader ? (function(e3) {
      var o3;
      function n2() {
        var r2;
        try {
          r2 = e3.read();
        } catch (e4) {
          return d(e4);
        }
        return m(r2, function(e4) {
          if (!t(e4)) throw new TypeError("The promise returned by the reader.read() method must fulfill with an object");
          if (e4.done) kt(o3._readableStreamController);
          else {
            var r3 = e4.value;
            At(o3._readableStreamController, r3);
          }
        });
      }
      function i2(r2) {
        try {
          return f(e3.cancel(r2));
        } catch (e4) {
          return d(e4);
        }
      }
      return o3 = Gt(r, n2, i2, 0), o3;
    })(e2.getReader()) : (function(e3) {
      var o3, n2 = ye(e3, "async");
      function i2() {
        var e4;
        try {
          e4 = ge(n2);
        } catch (e5) {
          return d(e5);
        }
        return m(f(e4), function(e5) {
          if (!t(e5)) throw new TypeError("The promise returned by the iterator.next() method must fulfill with an object");
          if (e5.done) kt(o3._readableStreamController);
          else {
            var r2 = e5.value;
            At(o3._readableStreamController, r2);
          }
        });
      }
      function a2(e4) {
        var r2, o4 = n2.iterator;
        try {
          r2 = he(o4, "return");
        } catch (e5) {
          return d(e5);
        }
        return void 0 === r2 ? f(void 0) : m(S(r2, o4, [e4]), function(e5) {
          if (!t(e5)) throw new TypeError("The promise returned by the iterator.return() method must fulfill with an object");
        });
      }
      return o3 = Gt(r, i2, a2, 0), o3;
    })(e2);
    var o2;
  }
  function xt(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return S(e2, r2, [t3]);
    };
  }
  function Qt(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return S(e2, r2, [t3]);
    };
  }
  function Nt(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return g(e2, r2, [t3]);
    };
  }
  function Ht(e2, r2) {
    if ("bytes" !== (e2 = "".concat(e2))) throw new TypeError("".concat(r2, " '").concat(e2, "' is not a valid enumeration value for ReadableStreamType"));
    return e2;
  }
  function Vt(e2, r2) {
    I(e2, r2);
    var t2 = null == e2 ? void 0 : e2.preventAbort, o2 = null == e2 ? void 0 : e2.preventCancel, n2 = null == e2 ? void 0 : e2.preventClose, i2 = null == e2 ? void 0 : e2.signal;
    return void 0 !== i2 && (function(e3, r3) {
      if (!(function(e4) {
        if ("object" != typeof e4 || null === e4) return false;
        try {
          return "boolean" == typeof e4.aborted;
        } catch (e5) {
          return false;
        }
      })(e3)) throw new TypeError("".concat(r3, " is not an AbortSignal."));
    })(i2, "".concat(r2, " has member 'signal' that")), { preventAbort: Boolean(t2), preventCancel: Boolean(o2), preventClose: Boolean(n2), signal: i2 };
  }
  Object.defineProperties(Et.prototype, { close: { enumerable: true }, enqueue: { enumerable: true }, error: { enumerable: true }, desiredSize: { enumerable: true } }), n(Et.prototype.close, "close"), n(Et.prototype.enqueue, "enqueue"), n(Et.prototype.error, "error"), "symbol" == typeof e.toStringTag && Object.defineProperty(Et.prototype, e.toStringTag, { value: "ReadableStreamDefaultController", configurable: true });
  var Ut = (function() {
    function ReadableStream(e2, r2) {
      void 0 === e2 && (e2 = {}), void 0 === r2 && (r2 = {}), void 0 === e2 ? e2 = null : Y(e2, "First parameter");
      var t2 = Tr(r2, "Second parameter"), o2 = (function(e3, r3) {
        I(e3, r3);
        var t3 = e3, o3 = null == t3 ? void 0 : t3.autoAllocateChunkSize, n3 = null == t3 ? void 0 : t3.cancel, i2 = null == t3 ? void 0 : t3.pull, a2 = null == t3 ? void 0 : t3.start, u2 = null == t3 ? void 0 : t3.type;
        return { autoAllocateChunkSize: void 0 === o3 ? void 0 : V(o3, "".concat(r3, " has member 'autoAllocateChunkSize' that")), cancel: void 0 === n3 ? void 0 : xt(n3, t3, "".concat(r3, " has member 'cancel' that")), pull: void 0 === i2 ? void 0 : Qt(i2, t3, "".concat(r3, " has member 'pull' that")), start: void 0 === a2 ? void 0 : Nt(a2, t3, "".concat(r3, " has member 'start' that")), type: void 0 === u2 ? void 0 : Ht(u2, "".concat(r3, " has member 'type' that")) };
      })(e2, "First parameter");
      if (Jt(this), "bytes" === o2.type) {
        if (void 0 !== t2.size) throw new RangeError("The strategy for a byte stream cannot have a size function");
        !(function(e3, r3, t3) {
          var o3, n3, i2, a2 = Object.create(Ae.prototype);
          o3 = void 0 !== r3.start ? function() {
            return r3.start(a2);
          } : function() {
          }, n3 = void 0 !== r3.pull ? function() {
            return r3.pull(a2);
          } : function() {
            return f(void 0);
          }, i2 = void 0 !== r3.cancel ? function(e4) {
            return r3.cancel(e4);
          } : function() {
            return f(void 0);
          };
          var u2 = r3.autoAllocateChunkSize;
          if (0 === u2) throw new TypeError("autoAllocateChunkSize must be greater than 0");
          ur(e3, a2, o3, n3, i2, t3, u2);
        })(this, o2, wr(t2, 0));
      } else {
        var n2 = Rr(t2);
        !(function(e3, r3, t3, o3) {
          var n3, i2, a2, u2 = Object.create(Et.prototype);
          n3 = void 0 !== r3.start ? function() {
            return r3.start(u2);
          } : function() {
          }, i2 = void 0 !== r3.pull ? function() {
            return r3.pull(u2);
          } : function() {
            return f(void 0);
          }, a2 = void 0 !== r3.cancel ? function(e4) {
            return r3.cancel(e4);
          } : function() {
            return f(void 0);
          }, Lt(e3, u2, n3, i2, a2, t3, o3);
        })(this, o2, wr(t2, 1), n2);
      }
    }
    return Object.defineProperty(ReadableStream.prototype, "locked", { get: function() {
      if (!Kt(this)) throw to("locked");
      return Zt(this);
    }, enumerable: false, configurable: true }), ReadableStream.prototype.cancel = function(e2) {
      return void 0 === e2 && (e2 = void 0), Kt(this) ? Zt(this) ? d(new TypeError("Cannot cancel a stream that already has a reader")) : $t(this, e2) : d(to("cancel"));
    }, ReadableStream.prototype.getReader = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !Kt(this)) throw to("getReader");
      return void 0 === (function(e3, r2) {
        I(e3, r2);
        var t2 = null == e3 ? void 0 : e3.mode;
        return { mode: void 0 === t2 ? void 0 : cr(t2, "".concat(r2, " has member 'mode' that")) };
      })(e2, "First parameter").mode ? G(this) : fr(this);
    }, ReadableStream.prototype.pipeThrough = function(e2, r2) {
      if (void 0 === r2 && (r2 = {}), !Kt(this)) throw to("pipeThrough");
      x(e2, 1, "pipeThrough");
      var t2 = (function(e3, r3) {
        I(e3, r3);
        var t3 = null == e3 ? void 0 : e3.readable;
        Q(t3, "readable", "ReadableWritablePair"), U(t3, "".concat(r3, " has member 'readable' that"));
        var o3 = null == e3 ? void 0 : e3.writable;
        return Q(o3, "writable", "ReadableWritablePair"), Wr(o3, "".concat(r3, " has member 'writable' that")), { readable: t3, writable: o3 };
      })(e2, "First parameter"), o2 = Vt(r2, "Second parameter");
      if (Zt(this)) throw new TypeError("ReadableStream.prototype.pipeThrough cannot be used on a locked ReadableStream");
      if (zr(t2.writable)) throw new TypeError("ReadableStream.prototype.pipeThrough cannot be used on a locked WritableStream");
      return v(Rt(this, t2.writable, o2.preventClose, o2.preventAbort, o2.preventCancel, o2.signal)), t2.readable;
    }, ReadableStream.prototype.pipeTo = function(e2, r2) {
      if (void 0 === r2 && (r2 = {}), !Kt(this)) return d(to("pipeTo"));
      if (void 0 === e2) return d("Parameter 1 is required in 'pipeTo'.");
      if (!Ar(e2)) return d(new TypeError("ReadableStream.prototype.pipeTo's first argument must be a WritableStream"));
      var t2;
      try {
        t2 = Vt(r2, "Second parameter");
      } catch (e3) {
        return d(e3);
      }
      return Zt(this) ? d(new TypeError("ReadableStream.prototype.pipeTo cannot be used on a locked ReadableStream")) : zr(e2) ? d(new TypeError("ReadableStream.prototype.pipeTo cannot be used on a locked WritableStream")) : Rt(this, e2, t2.preventClose, t2.preventAbort, t2.preventCancel, t2.signal);
    }, ReadableStream.prototype.tee = function() {
      if (!Kt(this)) throw to("tee");
      return ce(Mt(this));
    }, ReadableStream.prototype.values = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !Kt(this)) throw to("values");
      var r2, t2, o2, n2, i2, a2 = (function(e3, r3) {
        I(e3, r3);
        var t3 = null == e3 ? void 0 : e3.preventCancel;
        return { preventCancel: Boolean(t3) };
      })(e2, "First parameter");
      return r2 = this, t2 = a2.preventCancel, o2 = G(r2), n2 = new Se(o2, t2), (i2 = Object.create(Re))._asyncIteratorImpl = n2, i2;
    }, ReadableStream.prototype[ve] = function(e2) {
      return this.values(e2);
    }, ReadableStream.from = function(e2) {
      return Yt(e2);
    }, ReadableStream;
  })();
  function Gt(e2, r2, t2, o2, n2) {
    void 0 === o2 && (o2 = 1), void 0 === n2 && (n2 = function() {
      return 1;
    });
    var i2 = Object.create(Ut.prototype);
    return Jt(i2), Lt(i2, Object.create(Et.prototype), e2, r2, t2, o2, n2), i2;
  }
  function Xt(e2, r2, t2) {
    var o2 = Object.create(Ut.prototype);
    return Jt(o2), ur(o2, Object.create(Ae.prototype), e2, r2, t2, 0, void 0), o2;
  }
  function Jt(e2) {
    e2._state = "readable", e2._reader = void 0, e2._storedError = void 0, e2._disturbed = false;
  }
  function Kt(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_readableStreamController") && e2 instanceof Ut);
  }
  function Zt(e2) {
    return void 0 !== e2._reader;
  }
  function $t(e2, t2) {
    if (e2._disturbed = true, "closed" === e2._state) return f(void 0);
    if ("errored" === e2._state) return d(e2._storedError);
    eo(e2);
    var o2 = e2._reader;
    if (void 0 !== o2 && vr(o2)) {
      var n2 = o2._readIntoRequests;
      o2._readIntoRequests = new w(), n2.forEach(function(e3) {
        e3._closeSteps(void 0);
      });
    }
    return m(e2._readableStreamController[P](t2), r);
  }
  function eo(e2) {
    e2._state = "closed";
    var r2 = e2._reader;
    if (void 0 !== r2 && (D(r2), ie(r2))) {
      var t2 = r2._readRequests;
      r2._readRequests = new w(), t2.forEach(function(e3) {
        e3._closeSteps();
      });
    }
  }
  function ro(e2, r2) {
    e2._state = "errored", e2._storedError = r2;
    var t2 = e2._reader;
    void 0 !== t2 && (z(t2, r2), ie(t2) ? le(t2, r2) : gr(t2, r2));
  }
  function to(e2) {
    return new TypeError("ReadableStream.prototype.".concat(e2, " can only be used on a ReadableStream"));
  }
  function oo(e2, r2) {
    I(e2, r2);
    var t2 = null == e2 ? void 0 : e2.highWaterMark;
    return Q(t2, "highWaterMark", "QueuingStrategyInit"), { highWaterMark: N(t2) };
  }
  Object.defineProperties(Ut, { from: { enumerable: true } }), Object.defineProperties(Ut.prototype, { cancel: { enumerable: true }, getReader: { enumerable: true }, pipeThrough: { enumerable: true }, pipeTo: { enumerable: true }, tee: { enumerable: true }, values: { enumerable: true }, locked: { enumerable: true } }), n(Ut.from, "from"), n(Ut.prototype.cancel, "cancel"), n(Ut.prototype.getReader, "getReader"), n(Ut.prototype.pipeThrough, "pipeThrough"), n(Ut.prototype.pipeTo, "pipeTo"), n(Ut.prototype.tee, "tee"), n(Ut.prototype.values, "values"), "symbol" == typeof e.toStringTag && Object.defineProperty(Ut.prototype, e.toStringTag, { value: "ReadableStream", configurable: true }), Object.defineProperty(Ut.prototype, ve, { value: Ut.prototype.values, writable: true, configurable: true });
  var no = function(e2) {
    return e2.byteLength;
  };
  n(no, "size");
  var io = (function() {
    function ByteLengthQueuingStrategy(e2) {
      x(e2, 1, "ByteLengthQueuingStrategy"), e2 = oo(e2, "First parameter"), this._byteLengthQueuingStrategyHighWaterMark = e2.highWaterMark;
    }
    return Object.defineProperty(ByteLengthQueuingStrategy.prototype, "highWaterMark", { get: function() {
      if (!uo(this)) throw ao("highWaterMark");
      return this._byteLengthQueuingStrategyHighWaterMark;
    }, enumerable: false, configurable: true }), Object.defineProperty(ByteLengthQueuingStrategy.prototype, "size", { get: function() {
      if (!uo(this)) throw ao("size");
      return no;
    }, enumerable: false, configurable: true }), ByteLengthQueuingStrategy;
  })();
  function ao(e2) {
    return new TypeError("ByteLengthQueuingStrategy.prototype.".concat(e2, " can only be used on a ByteLengthQueuingStrategy"));
  }
  function uo(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_byteLengthQueuingStrategyHighWaterMark") && e2 instanceof io);
  }
  Object.defineProperties(io.prototype, { highWaterMark: { enumerable: true }, size: { enumerable: true } }), "symbol" == typeof e.toStringTag && Object.defineProperty(io.prototype, e.toStringTag, { value: "ByteLengthQueuingStrategy", configurable: true });
  var lo = function() {
    return 1;
  };
  n(lo, "size");
  var so = (function() {
    function CountQueuingStrategy(e2) {
      x(e2, 1, "CountQueuingStrategy"), e2 = oo(e2, "First parameter"), this._countQueuingStrategyHighWaterMark = e2.highWaterMark;
    }
    return Object.defineProperty(CountQueuingStrategy.prototype, "highWaterMark", { get: function() {
      if (!fo(this)) throw co("highWaterMark");
      return this._countQueuingStrategyHighWaterMark;
    }, enumerable: false, configurable: true }), Object.defineProperty(CountQueuingStrategy.prototype, "size", { get: function() {
      if (!fo(this)) throw co("size");
      return lo;
    }, enumerable: false, configurable: true }), CountQueuingStrategy;
  })();
  function co(e2) {
    return new TypeError("CountQueuingStrategy.prototype.".concat(e2, " can only be used on a CountQueuingStrategy"));
  }
  function fo(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_countQueuingStrategyHighWaterMark") && e2 instanceof so);
  }
  function po(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return S(e2, r2, [t3]);
    };
  }
  function bo(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return g(e2, r2, [t3]);
    };
  }
  function ho(e2, r2, t2) {
    return M(e2, t2), function(t3, o2) {
      return S(e2, r2, [t3, o2]);
    };
  }
  function _o(e2, r2, t2) {
    return M(e2, t2), function(t3) {
      return S(e2, r2, [t3]);
    };
  }
  Object.defineProperties(so.prototype, { highWaterMark: { enumerable: true }, size: { enumerable: true } }), "symbol" == typeof e.toStringTag && Object.defineProperty(so.prototype, e.toStringTag, { value: "CountQueuingStrategy", configurable: true });
  var mo = (function() {
    function TransformStream(e2, r2, t2) {
      void 0 === e2 && (e2 = {}), void 0 === r2 && (r2 = {}), void 0 === t2 && (t2 = {}), void 0 === e2 && (e2 = null);
      var o2 = Tr(r2, "Second parameter"), n2 = Tr(t2, "Third parameter"), i2 = (function(e3, r3) {
        I(e3, r3);
        var t3 = null == e3 ? void 0 : e3.cancel, o3 = null == e3 ? void 0 : e3.flush, n3 = null == e3 ? void 0 : e3.readableType, i3 = null == e3 ? void 0 : e3.start, a3 = null == e3 ? void 0 : e3.transform, u3 = null == e3 ? void 0 : e3.writableType;
        return { cancel: void 0 === t3 ? void 0 : _o(t3, e3, "".concat(r3, " has member 'cancel' that")), flush: void 0 === o3 ? void 0 : po(o3, e3, "".concat(r3, " has member 'flush' that")), readableType: n3, start: void 0 === i3 ? void 0 : bo(i3, e3, "".concat(r3, " has member 'start' that")), transform: void 0 === a3 ? void 0 : ho(a3, e3, "".concat(r3, " has member 'transform' that")), writableType: u3 };
      })(e2, "First parameter");
      if (void 0 !== i2.readableType) throw new RangeError("Invalid readableType specified");
      if (void 0 !== i2.writableType) throw new RangeError("Invalid writableType specified");
      var a2, u2 = wr(n2, 0), l2 = Rr(n2), s2 = wr(o2, 1), p2 = Rr(o2);
      !(function(e3, r3, t3, o3, n3, i3) {
        function a3() {
          return r3;
        }
        function u3(r4) {
          return (function(e4, r5) {
            var t4 = e4._transformStreamController;
            if (e4._backpressure) {
              return m(e4._backpressureChangePromise, function() {
                var o4 = e4._writable;
                if ("erroring" === o4._state) throw o4._storedError;
                return qo(t4, r5);
              });
            }
            return qo(t4, r5);
          })(e3, r4);
        }
        function l3(r4) {
          return (function(e4, r5) {
            var t4 = e4._transformStreamController;
            if (void 0 !== t4._finishPromise) return t4._finishPromise;
            var o4 = e4._readable;
            t4._finishPromise = c(function(e5, r6) {
              t4._finishPromise_resolve = e5, t4._finishPromise_reject = r6;
            });
            var n4 = t4._cancelAlgorithm(r5);
            return Po(t4), b(n4, function() {
              return "errored" === o4._state ? Wo(t4, o4._storedError) : (zt(o4._readableStreamController, r5), Oo(t4)), null;
            }, function(e5) {
              return zt(o4._readableStreamController, e5), Wo(t4, e5), null;
            }), t4._finishPromise;
          })(e3, r4);
        }
        function s3() {
          return (function(e4) {
            var r4 = e4._transformStreamController;
            if (void 0 !== r4._finishPromise) return r4._finishPromise;
            var t4 = e4._readable;
            r4._finishPromise = c(function(e5, t5) {
              r4._finishPromise_resolve = e5, r4._finishPromise_reject = t5;
            });
            var o4 = r4._flushAlgorithm();
            return Po(r4), b(o4, function() {
              return "errored" === t4._state ? Wo(r4, t4._storedError) : (kt(t4._readableStreamController), Oo(r4)), null;
            }, function(e5) {
              return zt(t4._readableStreamController, e5), Wo(r4, e5), null;
            }), r4._finishPromise;
          })(e3);
        }
        function f2() {
          return (function(e4) {
            return wo(e4, false), e4._backpressureChangePromise;
          })(e3);
        }
        function d2(r4) {
          return (function(e4, r5) {
            var t4 = e4._transformStreamController;
            if (void 0 !== t4._finishPromise) return t4._finishPromise;
            var o4 = e4._writable;
            t4._finishPromise = c(function(e5, r6) {
              t4._finishPromise_resolve = e5, t4._finishPromise_reject = r6;
            });
            var n4 = t4._cancelAlgorithm(r5);
            return Po(t4), b(n4, function() {
              return "errored" === o4._state ? Wo(t4, o4._storedError) : (nt(o4._writableStreamController, r5), So(e4), Oo(t4)), null;
            }, function(r6) {
              return nt(o4._writableStreamController, r6), So(e4), Wo(t4, r6), null;
            }), t4._finishPromise;
          })(e3, r4);
        }
        e3._writable = (function(e4, r4, t4, o4, n4, i4) {
          void 0 === n4 && (n4 = 1), void 0 === i4 && (i4 = function() {
            return 1;
          });
          var a4 = Object.create(jr.prototype);
          return kr(a4), et(a4, Object.create(Zr.prototype), e4, r4, t4, o4, n4, i4), a4;
        })(a3, u3, s3, l3, t3, o3), e3._readable = Gt(a3, f2, d2, n3, i3), e3._backpressure = void 0, e3._backpressureChangePromise = void 0, e3._backpressureChangePromise_resolve = void 0, wo(e3, true), e3._transformStreamController = void 0;
      })(this, c(function(e3) {
        a2 = e3;
      }), s2, p2, u2, l2), (function(e3, r3) {
        var t3, o3, n3, i3 = Object.create(Ro.prototype);
        t3 = void 0 !== r3.transform ? function(e4) {
          return r3.transform(e4, i3);
        } : function(e4) {
          try {
            return Co(i3, e4), f(void 0);
          } catch (e5) {
            return d(e5);
          }
        };
        o3 = void 0 !== r3.flush ? function() {
          return r3.flush(i3);
        } : function() {
          return f(void 0);
        };
        n3 = void 0 !== r3.cancel ? function(e4) {
          return r3.cancel(e4);
        } : function() {
          return f(void 0);
        };
        !(function(e4, r4, t4, o4, n4) {
          r4._controlledTransformStream = e4, e4._transformStreamController = r4, r4._transformAlgorithm = t4, r4._flushAlgorithm = o4, r4._cancelAlgorithm = n4, r4._finishPromise = void 0, r4._finishPromise_resolve = void 0, r4._finishPromise_reject = void 0;
        })(e3, i3, t3, o3, n3);
      })(this, i2), void 0 !== i2.start ? a2(i2.start(this._transformStreamController)) : a2(void 0);
    }
    return Object.defineProperty(TransformStream.prototype, "readable", { get: function() {
      if (!vo(this)) throw jo("readable");
      return this._readable;
    }, enumerable: false, configurable: true }), Object.defineProperty(TransformStream.prototype, "writable", { get: function() {
      if (!vo(this)) throw jo("writable");
      return this._writable;
    }, enumerable: false, configurable: true }), TransformStream;
  })();
  function vo(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_transformStreamController") && e2 instanceof mo);
  }
  function yo(e2, r2) {
    zt(e2._readable._readableStreamController, r2), go(e2, r2);
  }
  function go(e2, r2) {
    Po(e2._transformStreamController), nt(e2._writable._writableStreamController, r2), So(e2);
  }
  function So(e2) {
    e2._backpressure && wo(e2, false);
  }
  function wo(e2, r2) {
    void 0 !== e2._backpressureChangePromise && e2._backpressureChangePromise_resolve(), e2._backpressureChangePromise = c(function(r3) {
      e2._backpressureChangePromise_resolve = r3;
    }), e2._backpressure = r2;
  }
  Object.defineProperties(mo.prototype, { readable: { enumerable: true }, writable: { enumerable: true } }), "symbol" == typeof e.toStringTag && Object.defineProperty(mo.prototype, e.toStringTag, { value: "TransformStream", configurable: true });
  var Ro = (function() {
    function TransformStreamDefaultController() {
      throw new TypeError("Illegal constructor");
    }
    return Object.defineProperty(TransformStreamDefaultController.prototype, "desiredSize", { get: function() {
      if (!To(this)) throw Eo("desiredSize");
      return Dt(this._controlledTransformStream._readable._readableStreamController);
    }, enumerable: false, configurable: true }), TransformStreamDefaultController.prototype.enqueue = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !To(this)) throw Eo("enqueue");
      Co(this, e2);
    }, TransformStreamDefaultController.prototype.error = function(e2) {
      if (void 0 === e2 && (e2 = void 0), !To(this)) throw Eo("error");
      var r2;
      r2 = e2, yo(this._controlledTransformStream, r2);
    }, TransformStreamDefaultController.prototype.terminate = function() {
      if (!To(this)) throw Eo("terminate");
      !(function(e2) {
        var r2 = e2._controlledTransformStream;
        kt(r2._readable._readableStreamController);
        var t2 = new TypeError("TransformStream terminated");
        go(r2, t2);
      })(this);
    }, TransformStreamDefaultController;
  })();
  function To(e2) {
    return !!t(e2) && (!!Object.prototype.hasOwnProperty.call(e2, "_controlledTransformStream") && e2 instanceof Ro);
  }
  function Po(e2) {
    e2._transformAlgorithm = void 0, e2._flushAlgorithm = void 0, e2._cancelAlgorithm = void 0;
  }
  function Co(e2, r2) {
    var t2 = e2._controlledTransformStream, o2 = t2._readable._readableStreamController;
    if (!Ft(o2)) throw new TypeError("Readable side is not in a state that permits enqueue");
    try {
      At(o2, r2);
    } catch (e3) {
      throw go(t2, e3), t2._readable._storedError;
    }
    var n2 = (function(e3) {
      return !jt(e3);
    })(o2);
    n2 !== t2._backpressure && wo(t2, true);
  }
  function qo(e2, r2) {
    return m(e2._transformAlgorithm(r2), void 0, function(r3) {
      throw yo(e2._controlledTransformStream, r3), r3;
    });
  }
  function Eo(e2) {
    return new TypeError("TransformStreamDefaultController.prototype.".concat(e2, " can only be used on a TransformStreamDefaultController"));
  }
  function Oo(e2) {
    void 0 !== e2._finishPromise_resolve && (e2._finishPromise_resolve(), e2._finishPromise_resolve = void 0, e2._finishPromise_reject = void 0);
  }
  function Wo(e2, r2) {
    void 0 !== e2._finishPromise_reject && (v(e2._finishPromise), e2._finishPromise_reject(r2), e2._finishPromise_resolve = void 0, e2._finishPromise_reject = void 0);
  }
  function jo(e2) {
    return new TypeError("TransformStream.prototype.".concat(e2, " can only be used on a TransformStream"));
  }
  Object.defineProperties(Ro.prototype, { enqueue: { enumerable: true }, error: { enumerable: true }, terminate: { enumerable: true }, desiredSize: { enumerable: true } }), n(Ro.prototype.enqueue, "enqueue"), n(Ro.prototype.error, "error"), n(Ro.prototype.terminate, "terminate"), "symbol" == typeof e.toStringTag && Object.defineProperty(Ro.prototype, e.toStringTag, { value: "TransformStreamDefaultController", configurable: true });
  var Bo = { ReadableStream: Ut, ReadableStreamDefaultController: Et, ReadableByteStreamController: Ae, ReadableStreamBYOBRequest: ke, ReadableStreamDefaultReader: $, ReadableStreamBYOBReader: hr, WritableStream: jr, WritableStreamDefaultController: Zr, WritableStreamDefaultWriter: Nr, ByteLengthQueuingStrategy: io, CountQueuingStrategy: so, TransformStream: mo, TransformStreamDefaultController: Ro };
  for (var ko in Bo) Object.prototype.hasOwnProperty.call(Bo, ko) && Object.defineProperty(gt, ko, { value: Bo[ko], writable: true, configurable: true });
})();
