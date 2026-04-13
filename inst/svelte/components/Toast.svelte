<script>
  // Toast — Lightweight notification pop-ups
  //
  // Listens for 'ambolt:toast' window events and shows a brief message
  // that auto-dismisses after a few seconds.

  let toasts = $state([]);
  let nextId = 0;

  function addToast(message, type = 'info', action = null) {
    const id = nextId++;
    const duration = action ? 8000 : 4000;
    toasts = [...toasts, { id, message, type, action }];
    setTimeout(() => {
      toasts = toasts.filter(t => t.id !== id);
    }, duration);
  }

  function dismissToast(id) {
    toasts = toasts.filter(t => t.id !== id);
  }

  function handleAction(toast) {
    if (toast.action?.modal) {
      window.dispatchEvent(new CustomEvent('ambolt:open-modal', {
        detail: { modal: toast.action.modal, size: toast.action.size || 'lg' }
      }));
    }
    dismissToast(toast.id);
  }

  $effect(() => {
    function handleToast(e) {
      const detail = e.detail || {};
      addToast(detail.message || 'Klart!', detail.type || 'info', detail.action || null);
    }
    window.addEventListener('ambolt:toast', handleToast);
    return () => window.removeEventListener('ambolt:toast', handleToast);
  });
</script>

<div class="toast-container">
  {#each toasts as toast (toast.id)}
    <div class="toast toast-{toast.type}" class:has-action={toast.action}>
      {#if toast.type === 'success'}
        <i class="bi bi-check-circle"></i>
      {:else if toast.type === 'error'}
        <i class="bi bi-exclamation-circle"></i>
      {:else}
        <i class="bi bi-info-circle"></i>
      {/if}
      <span>{toast.message}</span>
      {#if toast.action}
        <button class="toast-action" onclick={() => handleAction(toast)}>
          {toast.action.label || 'Öppna'}
        </button>
      {/if}
    </div>
  {/each}
</div>

<style>
  .toast-container {
    position: fixed;
    bottom: 1.5rem;
    right: 1.5rem;
    z-index: 2000;
    display: flex;
    flex-direction: column-reverse;
    gap: 0.5rem;
    pointer-events: none;
  }
  .toast {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.6rem 1rem;
    border-radius: 6px;
    font-size: 0.85rem;
    font-family: var(--ambolt-font, system-ui, sans-serif);
    box-shadow: 0 2px 12px rgba(0,0,0,0.12);
    animation: toast-in 0.3s ease;
    pointer-events: auto;
  }
  .toast-info {
    background: #006589;
    color: white;
  }
  .toast-success {
    background: #15803d;
    color: white;
  }
  .toast-error {
    background: #710049;
    color: white;
  }
  .toast-action {
    margin-left: 0.5rem;
    padding: 0.2rem 0.6rem;
    border: 1px solid rgba(255,255,255,0.5);
    border-radius: 4px;
    background: rgba(255,255,255,0.15);
    color: white;
    font-size: 0.8rem;
    cursor: pointer;
    white-space: nowrap;
  }
  .toast-action:hover {
    background: rgba(255,255,255,0.3);
  }
  @keyframes toast-in {
    from { transform: translateY(1rem); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
</style>
