// basketStore — Persistent basket for collecting data series across searches.
//
// Follows the same singleton pattern as modalStore.svelte.js.
// Items survive across mode switches (landing → results → explorer)
// because Svelte module-scoped $state persists for the app lifetime.
//
// Usage:
//   import { basket } from 'ambolt';
//   basket.add({ value: 'kolada:N01951', label: 'Invånare totalt', source: 'KOLADA' });
//   basket.items  // reactive array
//   basket.count  // reactive count

let items = $state([]);
let isOpen = $state(false);

function add(item) {
  // Avoid duplicates by value
  if (items.some(i => i.value === item.value)) return;
  items = [...items, {
    value: item.value,
    label: item.label,
    source: item.source ?? '',
    category: item.category ?? '',
    description: item.description ?? '',
  }];
  // Auto-open when first item is added
  if (items.length === 1) isOpen = true;
}

function remove(value) {
  items = items.filter(i => i.value !== value);
  // Auto-close when empty
  if (items.length === 0) isOpen = false;
}

function clear() {
  items = [];
  isOpen = false;
}

function toggle() {
  isOpen = !isOpen;
}

function has(value) {
  return items.some(i => i.value === value);
}

export const basket = {
  get items() { return items; },
  get isOpen() { return isOpen; },
  get count() { return items.length; },
  add,
  remove,
  clear,
  toggle,
  has,
};

// Expose basket globally for debug URL support
if (typeof window !== 'undefined') {
  window.__basket = basket;
}
