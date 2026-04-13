// modalStore.svelte.js — Navigation stack for modal dialogs
//
// Supports nested modals: contact_profile → party_profile → back.
// Each entry has { id, params, title, html, size, loading }.
//
// Usage:
//   import { modal } from 'ambolt';
//   modal.open('contact_profile', { id: 123 });

let stack = $state([]);
let current = $derived(stack.length > 0 ? stack[stack.length - 1] : null);
let isOpen = $derived(stack.length > 0);

function open(id, params = {}, options = {}) {
  const entry = {
    id,
    params,
    size: options.size || 'md',
    title: options.title || '',
    html: options.html || null,
    loading: true
  };
  stack = [...stack, entry];

  // Fetch content from modal endpoint
  const url = new URL(`/api/modal/${id}`, window.location.origin);
  for (const [key, val] of Object.entries(params)) {
    if (val != null) url.searchParams.set(key, val);
  }

  fetch(url)
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then(data => {
      // Update the entry in the stack (find by position)
      stack = stack.map((e, i) =>
        i === stack.length - 1 && e.id === id
          ? { ...e, title: data.title || e.title,
              html: data.html || null,
              header: data.header || null,
              fields: data.fields || null,
              submit: data.submit || null,
              content: data.content || null,
              loading: false }
          : e
      );
    })
    .catch(err => {
      stack = stack.map((e, i) =>
        i === stack.length - 1 && e.id === id
          ? { ...e, title: 'Fel', html: `<p class="error">Kunde inte ladda: ${err.message}</p>`, loading: false }
          : e
      );
    });
}

function openLocal(options = {}) {
  // Open a modal with local content (no endpoint fetch)
  const entry = {
    id: options.id || '_local',
    params: {},
    size: options.size || 'md',
    title: options.title || '',
    html: options.html || '',
    loading: false
  };
  stack = [...stack, entry];
}

function close() {
  if (stack.length > 0) {
    stack = stack.slice(0, -1);
  }
}

function closeAll() {
  stack = [];
}

function refresh() {
  if (stack.length === 0) return;
  const entry = stack[stack.length - 1];
  // Re-fetch content for the current top modal
  const url = new URL(`/api/modal/${entry.id}`, window.location.origin);
  for (const [key, val] of Object.entries(entry.params || {})) {
    if (val != null) url.searchParams.set(key, val);
  }
  fetch(url)
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    })
    .then(data => {
      stack = stack.map((e, i) =>
        i === stack.length - 1
          ? { ...e, title: data.title || e.title,
              html: data.html || null,
              header: data.header || null,
              fields: data.fields || null,
              submit: data.submit || null,
              content: data.content || null,
              loading: false }
          : e
      );
    })
    .catch(() => { /* silently ignore refresh errors */ });
}

export const modal = {
  get stack() { return stack; },
  get current() { return current; },
  get isOpen() { return isOpen; },
  open,
  openLocal,
  close,
  closeAll,
  refresh
};
