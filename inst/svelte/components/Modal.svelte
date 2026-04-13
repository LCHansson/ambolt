<script>
  // Modal — Dialog component for ambolt apps
  //
  // Renders the modal stack from modalStore. Supports nested modals
  // (push/pop), backdrop dismiss, escape key, size variants.
  //
  // Usage: place <Modal /> once in the app layout. Modal content is
  // fetched from server endpoints or provided locally via modalStore.

  import { modal } from './modalStore.svelte.js';
  import FormBody from './FormBody.svelte';
  import RenderNode from './RenderNode.svelte';
  import { postData, putData, deleteData } from './mutations.js';

  // Track per-modal submit state for HTML-body modals
  let htmlSubmitting = $state(false);
  let htmlSubmitError = $state('');

  // Submit handler for HTML-body modals with a submit config.
  // Collects all named <input>, <textarea>, <select> from the modal body.
  async function handleHtmlSubmit(entry) {
    const modalBody = document.querySelector('.ambolt-modal.top .ambolt-modal-body');
    if (!modalBody) return;

    const formData = {};
    modalBody.querySelectorAll('input[name], textarea[name], select[name]').forEach(el => {
      formData[el.name] = el.value;
    });

    htmlSubmitting = true;
    htmlSubmitError = '';
    try {
      const method = (entry.submit.method || 'POST').toUpperCase();
      const endpoint = entry.submit.endpoint || '';
      let responseData;
      if (method === 'DELETE') {
        responseData = await deleteData(endpoint);
      } else if (method === 'PUT') {
        responseData = await putData(endpoint, formData);
      } else {
        responseData = await postData(endpoint, formData);
      }

      // If submit config specifies a follow-up modal, open it with response data as params
      if (entry.submit.open_modal) {
        modal.close();
        const params = responseData || {};
        const size = entry.submit.open_modal_size || 'md';
        setTimeout(() => modal.open(entry.submit.open_modal, params, { size }), 100);
      } else {
        modal.close();
        modal.refresh();
      }
    } catch (err) {
      htmlSubmitError = err.message || 'Ett fel uppstod';
    } finally {
      htmlSubmitting = false;
    }
  }

  // Close on escape key
  function handleKeydown(e) {
    if (e.key === 'Escape' && modal.isOpen) {
      modal.close();
    }
  }

  // Close all modals on backdrop click
  function handleBackdrop(e) {
    if (e.target === e.currentTarget) {
      modal.closeAll();
    }
  }

  // Handle data-modal link clicks and data-ambolt-action buttons (delegated)
  $effect(() => {
    function handleClick(e) {
      // Modal links: data-modal attribute
      const link = e.target.closest('[data-modal]');
      if (link) {
        e.preventDefault();
        const attr = link.getAttribute('data-modal');
        // Parse "modal_id?param1=val1&param2=val2"
        const [modalId, queryStr] = attr.split('?');
        const params = {};
        if (queryStr) {
          for (const part of queryStr.split('&')) {
            const [key, val] = part.split('=');
            params[decodeURIComponent(key)] = decodeURIComponent(val || '');
          }
        }
        const size = link.getAttribute('data-modal-size') || 'md';
        modal.open(modalId, params, { size });
        return;
      }

      // Declarative actions: data-ambolt-action attribute
      const actionEl = e.target.closest('[data-ambolt-action]');
      if (actionEl) {
        e.preventDefault();
        handleAction(actionEl);
      }
    }

    // Declarative action handler — reads data-ambolt-* attributes and
    // executes fetch + post-action effects (toast, emit, remove, modal)
    async function handleAction(el) {
      const method = (el.getAttribute('data-ambolt-action') || 'post').toUpperCase();
      const endpoint = el.getAttribute('data-ambolt-endpoint');
      if (!endpoint || !endpoint.startsWith('/api/')) return;

      const bodyStr = el.getAttribute('data-ambolt-body');
      const toastMsg = el.getAttribute('data-ambolt-toast');
      const emitEvent = el.getAttribute('data-ambolt-emit');
      const removeSelector = el.getAttribute('data-ambolt-remove');
      const modalRefresh = el.hasAttribute('data-ambolt-modal-refresh');
      const openModalId = el.getAttribute('data-ambolt-open-modal');
      const openModalSize = el.getAttribute('data-ambolt-open-modal-size') || 'sm';

      el.disabled = true;

      try {
        const fetchOpts = { method, headers: { 'Content-Type': 'application/json' } };
        if (bodyStr) fetchOpts.body = bodyStr;
        else if (method !== 'GET' && method !== 'DELETE') fetchOpts.body = '{}';

        const res = await fetch(endpoint, fetchOpts);
        if (!res.ok) {
          let msg = `HTTP ${res.status}`;
          try { const d = await res.json(); if (d.error) msg = d.error; } catch {}
          throw new Error(msg);
        }

        let data = {};
        try { data = await res.json(); } catch {}

        // Post-action effects
        if (toastMsg) {
          window.dispatchEvent(new CustomEvent('ambolt:toast', {
            detail: { message: data.toast || toastMsg, type: 'success' }
          }));
        }
        if (emitEvent) {
          window.dispatchEvent(new CustomEvent('ambolt:event', {
            detail: { event: emitEvent }
          }));
        }
        if (removeSelector) {
          const ancestor = el.closest(removeSelector);
          if (ancestor) ancestor.remove();
        }
        if (modalRefresh) {
          modal.refresh();
        }
        if (openModalId) {
          const [mid, qs] = openModalId.split('?');
          const p = {};
          if (qs) {
            for (const part of qs.split('&')) {
              const [k, v] = part.split('=');
              p[decodeURIComponent(k)] = decodeURIComponent(v || '');
            }
          }
          setTimeout(() => modal.open(mid, p, { size: openModalSize }), 150);
        }
      } catch (err) {
        window.dispatchEvent(new CustomEvent('ambolt:toast', {
          detail: { message: err.message || 'Ett fel uppstod', type: 'error' }
        }));
        el.disabled = false;
      }
    }

    document.addEventListener('click', handleClick);

    // Listen for modal refresh requests from raw HTML
    function handleRefreshEvent() { modal.refresh(); }
    window.addEventListener('ambolt:modal-refresh', handleRefreshEvent);

    // Listen for programmatic modal open requests (e.g., from toast actions)
    function handleOpenModal(e) {
      const { modal: modalAttr, size } = e.detail || {};
      if (!modalAttr) return;
      const [modalId, queryStr] = modalAttr.split('?');
      const params = {};
      if (queryStr) {
        for (const part of queryStr.split('&')) {
          const [key, val] = part.split('=');
          params[decodeURIComponent(key)] = decodeURIComponent(val || '');
        }
      }
      modal.open(modalId, params, { size: size || 'md' });
    }
    window.addEventListener('ambolt:open-modal', handleOpenModal);

    return () => {
      document.removeEventListener('click', handleClick);
      window.removeEventListener('ambolt:modal-refresh', handleRefreshEvent);
      window.removeEventListener('ambolt:open-modal', handleOpenModal);
    };
  });

  // Execute <script> tags in {@html} content (innerHTML doesn't run scripts).
  // Still needed because DSL modals frequently wrap legacy HTML in html_block
  // nodes that contain inline <script> blocks (e.g. the position filter in
  // the party modal). When the entire app uses real Svelte event handlers
  // inside DSL nodes, this effect can be removed.
  $effect(() => {
    if (!modal.isOpen) return;
    // Re-run when the visible content changes
    const _ = modal.current?.html || modal.current?.content;
    requestAnimationFrame(() => {
      const body = document.querySelector('.ambolt-modal.top .ambolt-modal-body');
      if (!body) return;
      body.querySelectorAll('script:not([data-executed])').forEach(script => {
        script.setAttribute('data-executed', '');
        const newScript = document.createElement('script');
        newScript.textContent = script.textContent;
        document.head.appendChild(newScript).remove();
      });
    });
  });

  const sizeWidths = { sm: '400px', md: '600px', lg: 'min(90vw, 1200px)', xl: 'min(95vw, 1500px)' };
</script>

<svelte:window onkeydown={handleKeydown} />

{#if modal.isOpen}
  {@const entry = modal.current}
  {@const hasBack = modal.stack.length > 1}
  {@const prevTitle = hasBack ? modal.stack[modal.stack.length - 2].title : ''}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="ambolt-modal-backdrop" role="presentation" onclick={handleBackdrop}>
      <div
        class="ambolt-modal top"
        style="--modal-width: {sizeWidths[entry.size] || sizeWidths.md};"
      >
        <div class="ambolt-modal-header">
          {#if hasBack}
            <button class="ambolt-modal-back" onclick={() => modal.close()}>
              ← {prevTitle || 'Tillbaka'}
            </button>
          {/if}
          <h2 class="ambolt-modal-title">
            {entry.loading ? 'Laddar...' : entry.title}
          </h2>
          <button class="ambolt-modal-close" onclick={() => modal.closeAll()}>×</button>
        </div>
        <div class="ambolt-modal-body">
          {#if entry.loading}
            <p class="loading">Laddar innehåll...</p>
          {:else if entry.fields}
            <FormBody fields={entry.fields} submit={entry.submit}
              onSuccess={() => { modal.close(); modal.refresh(); }} />
          {:else if entry.content}
            <RenderNode node={entry.content} />
            {#if entry.submit}
              {#if htmlSubmitError}
                <div class="form-error-banner" style="margin-top:0.75rem;">{htmlSubmitError}</div>
              {/if}
              <div class="form-actions" style="margin-top:0.75rem;">
                <button
                  class="form-submit"
                  class:danger={entry.submit.style === 'danger'}
                  disabled={htmlSubmitting}
                  onclick={() => handleHtmlSubmit(entry)}
                >{htmlSubmitting ? 'Sparar...' : (entry.submit.label || 'Spara')}</button>
              </div>
            {/if}
          {:else}
            {@html entry.html}
            {#if entry.submit}
              {#if htmlSubmitError}
                <div class="form-error-banner" style="margin-top:0.75rem;">{htmlSubmitError}</div>
              {/if}
              <div class="form-actions" style="margin-top:0.75rem;">
                <button
                  class="form-submit"
                  class:danger={entry.submit.style === 'danger'}
                  disabled={htmlSubmitting}
                  onclick={() => handleHtmlSubmit(entry)}
                >{htmlSubmitting ? 'Sparar...' : (entry.submit.label || 'Spara')}</button>
              </div>
            {/if}
          {/if}
        </div>
      </div>
  </div>
{/if}

<style>
  .ambolt-modal-backdrop {  /* Must be above hamburger (z-index 1001) and sidebar (1000) */
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding-top: 5vh;
    z-index: 1100;
    overflow-y: auto;
  }
  .ambolt-modal {
    background: white;
    border-radius: var(--ambolt-modal-radius, var(--ambolt-radius-lg, 8px));
    box-shadow: var(--ambolt-modal-shadow, 0 8px 40px rgba(0, 0, 0, 0.2));
    width: var(--modal-width, 560px);
    max-width: calc(100vw - 2rem);
    max-height: 85vh;
    display: flex;
    flex-direction: column;
    position: absolute;
    top: 5vh;
    opacity: 0.3;
    pointer-events: none;
    transition: opacity 0.15s;
  }
  .ambolt-modal.top {
    opacity: 1;
    pointer-events: auto;
  }
  .ambolt-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }
  .ambolt-modal-title {
    margin: 0;
    font-size: 1.2rem;
    font-weight: 600;
    color: #1f2937;
  }
  .ambolt-modal-back {
    background: none;
    border: none;
    color: var(--ambolt-primary, #006589);
    font-size: 0.8rem;
    cursor: pointer;
    padding: 0;
    margin-bottom: 0.25rem;
    display: block;
    text-align: left;
    max-width: 80%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .ambolt-modal-back:hover {
    text-decoration: underline;
  }
  .ambolt-modal-close {
    background: none;
    border: none;
    font-size: 1.5rem;
    color: #6b7280;
    cursor: pointer;
    padding: 0 0.25rem;
    line-height: 1;
  }
  .ambolt-modal-close:hover {
    color: #1f2937;
  }
  .ambolt-modal-body {
    padding: 1.25rem;
    overflow-y: auto;
    flex: 1;
  }
  .loading {
    color: #6b7280;
  }
  .modal-tab-bar {
    display: flex;
    gap: 0;
    border-bottom: 2px solid #d1d5db;
    margin: -0.25rem -0.25rem 1rem;
  }
  .modal-tab-bar button {
    padding: 0.5rem 1rem;
    border: none;
    background: none;
    font-size: 0.95rem;
    cursor: pointer;
    color: #6b7280;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    transition: color 0.15s, border-color 0.15s;
  }
  .modal-tab-bar button:hover {
    color: #374151;
  }
  .modal-tab-bar button.active {
    color: var(--ambolt-primary, #4f46e5);
    border-bottom-color: var(--ambolt-primary, #4f46e5);
    font-weight: 600;
  }
  .modal-tab-badge {
    display: inline-block;
    background: #e5e7eb;
    color: #374151;
    border-radius: 10px;
    padding: 0 0.4rem;
    font-size: 0.75rem;
    margin-left: 0.3rem;
    font-weight: 500;
  }
  /* Submit button styles for HTML-body modals (mirrors FormBody) */
  .form-error-banner {
    background: #fef2f2;
    color: #dc2626;
    border: 1px solid #fecaca;
    border-radius: 4px;
    padding: 0.5rem 0.75rem;
    font-size: 0.9rem;
  }
  .form-actions {
    display: flex;
    justify-content: flex-end;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e7eb;
  }
  .form-submit {
    padding: 0.5rem 1.25rem;
    background: var(--ambolt-primary, #4f46e5);
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 0.95rem;
    font-weight: 500;
    cursor: pointer;
  }
  .form-submit:hover:not(:disabled) {
    opacity: 0.9;
  }
  .form-submit:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .form-submit.danger {
    background: var(--ambolt-danger, #dc2626);
  }
  @media (max-width: 640px) {
    .ambolt-modal {
      width: calc(100vw - 1rem);
      max-height: 92vh;
      top: 2vh;
    }
    .ambolt-modal-header {
      padding: 0.75rem 1rem;
      font-size: 0.95rem;
    }
    .ambolt-modal-body {
      padding: 0.75rem 1rem;
    }
    .modal-tab-bar {
      gap: 0;
    }
    .modal-tab-bar button {
      font-size: 0.8rem;
      padding: 0.4rem 0.6rem;
    }
  }
</style>
