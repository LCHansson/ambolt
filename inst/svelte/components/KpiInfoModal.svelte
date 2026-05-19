<script>
  // KpiInfoModal — full metadata for a search hit. Lazy-fetches from
  // host app's /api/kpi_info endpoint when opened. Used by
  // SearchResultsPanel's "Visa mer"-button.
  //
  // Props:
  //   value    — "source:entity_id" string (same format as search hits)
  //   baseUrl  — API base URL (default: window.location.origin)
  //   onClose  — callback when user dismisses the modal

  let {
    value = null,
    baseUrl = '',
    onClose = () => {},
  } = $props();

  let info = $state(null);
  let loading = $state(true);
  let dialogEl;

  $effect(() => {
    if (!value) return;
    loading = true;
    info = null;
    const base = baseUrl || window.location.origin;
    const url = new URL('/api/kpi_info', base);
    url.searchParams.set('value', value);
    fetch(url.toString())
      .then(r => r.json())
      .then(d => { info = d; loading = false; })
      .catch(() => { info = { error: 'Kunde inte ladda info' }; loading = false; });
  });

  $effect(() => {
    if (dialogEl && !dialogEl.open) {
      dialogEl.showModal();
    }
  });

  function handleBackdropClick(e) {
    if (e.target === dialogEl) onClose();
  }

  const sourceLabels = {
    pixieweb: 'SCB',
    kolada: 'Kolada',
    trafa: 'Trafikanalys'
  };

  // Render plain text with markdown-style links [label](url) as <a>.
  // Escapes HTML first to prevent injection from upstream metadata.
  function richText(text) {
    if (!text) return '';
    const escaped = String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
    return escaped.replace(
      /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
      '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>'
    );
  }
</script>

<dialog bind:this={dialogEl} class="kim" onclick={handleBackdropClick}
        onclose={onClose}>
  <div class="kim-inner">
    <button type="button" class="kim-close" onclick={onClose}
            aria-label="Stäng">×</button>

    {#if loading}
      <p class="kim-loading">Laddar…</p>
    {:else if info?.error}
      <p class="kim-error">Kunde inte ladda info: {info.error}</p>
    {:else if info}
      <h2 class="kim-title">{info.title ?? info.entity_id}</h2>
      <p class="kim-sub">
        <span class="kim-source">{sourceLabels[info.source] ?? info.source}</span>
        <span class="kim-id">{info.entity_id}</span>
        {#if info.category}<span class="kim-cat">{info.category}</span>{/if}
      </p>

      {#if info.description || info.contents}
        <h3>Beskrivning</h3>
        {#if info.description}<p>{@html richText(info.description)}</p>{/if}
        {#if info.contents && info.contents !== info.description}
          <p>{@html richText(info.contents)}</p>
        {/if}
      {/if}

      {#if info.subject_area || info.publ_period || info.product_label || info.contact || (info.notes && info.notes.length)}
        <dl class="kim-meta">
          {#if info.subject_area}
            <dt>Ämnesområde</dt><dd>{info.subject_area}</dd>
          {/if}
          {#if info.publ_period}
            <dt>Senast publicerad</dt><dd>{info.publ_period}</dd>
          {/if}
          {#if info.product_label}
            <dt>Trafa-produkt</dt><dd>{info.product_label}</dd>
          {/if}
          {#if info.contact}
            <dt>Kontakt</dt><dd>{@html richText(info.contact)}</dd>
          {/if}
          {#if info.notes && info.notes.length > 0}
            <dt>Anmärkningar</dt>
            <dd>{#each info.notes as n}<p>{@html richText(n)}</p>{/each}</dd>
          {/if}
        </dl>
      {/if}

      {#if info.source === 'pixieweb' && info.enriched === false}
        <p class="kim-hint">
          Utökad metadata för denna tabell hämtas i bakgrunden — kom tillbaka strax.
        </p>
      {/if}
    {/if}
  </div>
</dialog>

<style>
  .kim {
    border: none;
    border-radius: 12px;
    padding: 0;
    max-width: 720px;
    width: 90vw;
    max-height: 85vh;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.25);
  }
  .kim::backdrop {
    background: rgba(15, 23, 42, 0.45);
  }
  .kim-inner {
    padding: 1.5rem 1.75rem;
    overflow-y: auto;
    max-height: 85vh;
  }
  .kim-close {
    position: absolute;
    top: 0.6rem;
    right: 0.8rem;
    background: transparent;
    border: none;
    font-size: 1.5rem;
    line-height: 1;
    cursor: pointer;
    color: #4A5568;
  }
  .kim-close:hover { color: #1a202c; }
  .kim-loading, .kim-error {
    padding: 1rem 0;
    color: #4A5568;
    font-style: italic;
  }
  .kim-title {
    font-size: 1.25rem;
    margin: 0 0 0.3rem 0;
    color: #1a202c;
  }
  .kim-sub {
    display: flex;
    gap: 0.5rem;
    align-items: baseline;
    flex-wrap: wrap;
    margin: 0 0 1rem 0;
    font-size: 0.8rem;
  }
  .kim-source {
    font-weight: 600;
    color: #0B7A75;
    background: #EBF5F5;
    padding: 0.1rem 0.4rem;
    border-radius: 3px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    font-size: 0.65rem;
  }
  .kim-id {
    font-family: ui-monospace, "SFMono-Regular", Menlo, Consolas, monospace;
    color: #A0AEC0;
  }
  .kim-cat {
    color: #0B7A75;
  }
  .kim-inner h3 {
    font-size: 0.85rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #4A5568;
    margin: 1rem 0 0.4rem 0;
  }
  .kim-inner p {
    line-height: 1.5;
    color: #2D3748;
    margin: 0 0 0.6rem 0;
  }
  .kim-meta {
    display: grid;
    grid-template-columns: max-content 1fr;
    column-gap: 1rem;
    row-gap: 0.4rem;
    margin: 0.5rem 0 0 0;
    font-size: 0.88rem;
  }
  .kim-meta dt {
    font-weight: 600;
    color: #4A5568;
  }
  .kim-meta dd {
    margin: 0;
    color: #2D3748;
  }
  .kim-meta dd p {
    margin: 0 0 0.3rem 0;
  }
  .kim-hint {
    margin-top: 1rem;
    padding: 0.5rem 0.75rem;
    background: #FEF3C7;
    color: #92400E;
    border-radius: 4px;
    font-size: 0.85rem;
    font-style: italic;
  }
</style>
