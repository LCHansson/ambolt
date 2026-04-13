// eventBus.svelte.js — Pub/sub event bus for cross-module communication
//
// Replaces Shiny's reactiveVal + observeEvent chains with explicit
// publish/subscribe. Components emit events after mutations; listeners
// re-fetch their data.
//
// Usage:
//   import { events } from 'ambolt';
//   events.on('contacts:updated', () => loadContacts());
//   events.emit('contacts:updated');

let listeners = {};

function on(event, callback) {
  if (!listeners[event]) listeners[event] = [];
  listeners[event].push(callback);
}

function off(event, callback) {
  if (!listeners[event]) return;
  listeners[event] = listeners[event].filter(cb => cb !== callback);
}

function emit(event, data) {
  if (!listeners[event]) return;
  for (const cb of listeners[event]) {
    try { cb(data); } catch (e) { console.error(`Event "${event}" handler error:`, e); }
  }
}

// Bridge: listen for window CustomEvents from raw HTML (inline JS can't
// access the Svelte event bus directly, so they dispatch on window instead)
if (typeof window !== 'undefined') {
  window.addEventListener('ambolt:event', (e) => {
    const detail = e.detail;
    if (detail && detail.event) {
      emit(detail.event, detail);
    }
  });
}

export const events = { on, off, emit };
