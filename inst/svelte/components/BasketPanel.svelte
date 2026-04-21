<script>
  // BasketPanel — Fixed-position basket panel at the bottom of the viewport.
  //
  // Shows collected data series as mini-cards. Collapsible.
  // "Utforska data" button triggers exploration mode.
  //
  // Props:
  //   onExplore — callback() when "Utforska data" is clicked

  import { basket } from './basketStore.svelte.js';

  let {
    onExplore = () => {},
  } = $props();

  function handleExplore() {
    if (basket.count === 0) return;
    // Dispatch ambolt:select for the first basket item to enter explorer mode
    const first = basket.items[0];
    document.dispatchEvent(new CustomEvent('ambolt:select', {
      detail: { inputId: 'kpi_search', value: first.value, label: first.label }
    }));
    onExplore();
  }
</script>

{#if basket.count > 0}
  <div class="basket-panel" class:open={basket.isOpen}>
    {#if basket.isOpen}
      <!-- Expanded -->
      <div class="basket-header">
        <span class="basket-title">
          <i class="bi bi-basket2"></i>
          Korg ({basket.count} {basket.count === 1 ? 'serie' : 'serier'})
        </span>
        <div class="basket-header-actions">
          <button class="basket-link-btn" onclick={() => basket.clear()}>Rensa alla</button>
          <button class="basket-link-btn" onclick={() => basket.toggle()}>▼ Minimera</button>
        </div>
      </div>
      <div class="basket-items">
        {#each basket.items as item (item.value)}
          {@const idPart = item.value.includes(':') ? item.value.slice(item.value.indexOf(':') + 1) : item.value}
          {@const idDisplay = idPart.includes('\u001f') ? idPart.replace('\u001f', ' / ') : idPart}
          <div class="basket-item">
            <div class="basket-item-info">
              <span class="basket-item-title" title={item.label}>{item.label}</span>
              <span class="basket-item-meta">
                <span class="basket-item-source">{item.source}</span>
                <span class="basket-item-id">{idDisplay}</span>
              </span>
            </div>
            <button class="basket-item-remove" onclick={() => basket.remove(item.value)}
                    title="Ta bort">×</button>
          </div>
        {/each}
      </div>
      <div class="basket-footer">
        <button class="basket-explore-btn" onclick={handleExplore}>
          Utforska data →
        </button>
      </div>
    {:else}
      <!-- Collapsed -->
      <div class="basket-collapsed" onclick={() => basket.toggle()} role="button" tabindex="0">
        <span>
          <i class="bi bi-basket2"></i>
          {basket.count} {basket.count === 1 ? 'serie' : 'serier'} i korg
        </span>
        <span class="basket-collapsed-actions">
          <span class="basket-link-btn">▲ Visa</span>
          <button class="basket-explore-btn-sm" onclick={(e) => { e.stopPropagation(); handleExplore(); }}>
            Utforska data →
          </button>
        </span>
      </div>
    {/if}
  </div>
{/if}

<style>
  .basket-panel {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: white;
    border-top: 2px solid #0B7A75;
    box-shadow: 0 -4px 16px rgba(0,0,0,0.1);
    z-index: 100;
    font-family: var(--ambolt-font, system-ui, sans-serif);
  }
  .basket-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0.6rem 1.5rem;
    border-bottom: 1px solid #E2E8F0;
  }
  .basket-title {
    font-size: 0.9rem;
    font-weight: 600;
    color: #2D3748;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .basket-header-actions {
    display: flex;
    gap: 1rem;
  }
  .basket-link-btn {
    font-size: 0.78rem;
    color: #4A5568;
    background: none;
    border: none;
    cursor: pointer;
    font-family: inherit;
    padding: 0;
  }
  .basket-link-btn:hover {
    color: #0B7A75;
  }
  .basket-items {
    display: flex;
    gap: 0.5rem;
    padding: 0.75rem 1.5rem;
    overflow-x: auto;
    flex-wrap: wrap;
  }
  .basket-item {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.4rem 0.6rem;
    border: 1px solid #E2E8F0;
    border-radius: 6px;
    background: #F7FAFC;
    min-width: 0;
  }
  .basket-item-info {
    display: flex;
    flex-direction: column;
    min-width: 0;
  }
  .basket-item-title {
    font-size: 0.8rem;
    font-weight: 500;
    color: #2D3748;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 200px;
  }
  .basket-item-meta {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
  }
  .basket-item-source {
    font-size: 0.65rem;
    color: #0B7A75;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }
  .basket-item-id {
    font-size: 0.65rem;
    color: #A0AEC0;
    font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
  }
  .basket-item-remove {
    font-size: 1.1rem;
    color: #A0AEC0;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0 0.2rem;
    line-height: 1;
  }
  .basket-item-remove:hover {
    color: #E05A47;
  }
  .basket-footer {
    display: flex;
    justify-content: flex-end;
    padding: 0.5rem 1.5rem 0.75rem;
  }
  .basket-explore-btn {
    padding: 0.5rem 1.2rem;
    background: #0B7A75;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 0.88rem;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    transition: background 0.15s;
  }
  .basket-explore-btn:hover {
    background: #065956;
  }
  .basket-collapsed {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 0.6rem 1.5rem;
    background: white;
    border: none;
    cursor: pointer;
    font-family: inherit;
    font-size: 0.85rem;
    color: #2D3748;
  }
  .basket-collapsed span {
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .basket-collapsed-actions {
    display: flex;
    align-items: center;
    gap: 1rem;
  }
  .basket-explore-btn-sm {
    padding: 0.3rem 0.8rem;
    background: #0B7A75;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 0.78rem;
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
  }
  .basket-explore-btn-sm:hover {
    background: #065956;
  }
</style>
