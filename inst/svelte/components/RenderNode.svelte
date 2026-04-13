<script>
  // RenderNode — Runtime DSL tree walker for modal content.
  //
  // Recursive component that dispatches on node.type and renders the
  // corresponding Svelte component or markup. Mirrors the R codegen in
  // R/codegen_tree.R, but runs at request time instead of build time.
  //
  // Used by Modal.svelte when a modal endpoint returns `{ title, content }`
  // where content is a DSL tree.
  //
  // Supported node types:
  //   Layout primitives:
  //     page_content   — flex column container
  //     page_header    — title + subtitle + actions
  //     section        — labeled block with optional compact variant
  //     columns        — equal-width side-by-side columns
  //     details        — native collapsible <details>
  //     view_switcher  — tab bar + active view content
  //   Data-bound:
  //     stat_cards     — delegates to StatCards.svelte
  //     data_table     — delegates to DataTable.svelte
  //     create_button  — button/link with modal/navigate/download actions
  //   Escape hatch:
  //     html_block     — raw HTML (with optional class/style wrapper)

  // Self-import enables recursive rendering of children
  import Self from './RenderNode.svelte';
  import ViewSwitcher from './ViewSwitcher.svelte';
  import StatCards from './StatCards.svelte';
  import DataTable from './DataTable.svelte';
  import { modal } from './modalStore.svelte.js';

  let { node } = $props();

  // Open a modal directly (bypasses the global data-modal click delegation)
  function openModal(e, modalId, modalSize) {
    e.preventDefault();
    e.stopPropagation();
    const [id, queryStr] = modalId.split('?');
    const params = {};
    if (queryStr) {
      for (const part of queryStr.split('&')) {
        const [key, val] = part.split('=');
        params[decodeURIComponent(key)] = decodeURIComponent(val || '');
      }
    }
    modal.open(id, params, { size: modalSize || 'md' });
  }

  // Convert a DSL node's `style` field (object) to a CSS string for inline use.
  // Matches R's .style_to_string helper.
  function styleToString(style) {
    if (!style || typeof style !== 'object') return '';
    return Object.entries(style)
      .map(([k, v]) => `${k}:${v}`)
      .join(';');
  }

  // Lookup for view_switcher: map id -> children array
  function viewChildren(views, id) {
    const v = views?.find(v => v.id === id);
    return v?.children ?? [];
  }

  // Compute the CSS class string for a create_button node
  function buttonClass(n) {
    const base = (n.variant ?? 'primary') === 'primary'
      ? 'ambolt-action-btn ambolt-action-btn-primary'
      : 'ambolt-action-btn';
    return n.class ? `${base} ${n.class}` : base;
  }
</script>

{#if node}
  {#if node.type === 'page_content'}
    <div class="ambolt-page-content {node.class ?? ''}"
         style={styleToString({ ...(node.style ?? {}), ...(node.gap ? { gap: node.gap } : {}) })}>
      {#each node.children ?? [] as child}
        <Self node={child} />
      {/each}
    </div>

  {:else if node.type === 'page_header'}
    <div class="ambolt-page-header {node.class ?? ''}" style={styleToString(node.style)}>
      <div class="ambolt-page-header-title">
        <h2 class="ambolt-page-title">
          {node.title}
          {#if node.help}<span class="ambolt-page-help">{@html node.help}</span>{/if}
        </h2>
        {#if node.subtitle}
          <p class="ambolt-page-subtitle">{node.subtitle}</p>
        {/if}
      </div>
      {#if node.actions && node.actions.length > 0}
        <div class="ambolt-page-actions">
          {#each node.actions as action}
            <Self node={action} />
          {/each}
        </div>
      {/if}
    </div>

  {:else if node.type === 'section'}
    <div class="section {node.compact ? 'section-compact' : ''} {node.class ?? ''}"
         style={styleToString(node.style)}>
      {#if node.label}
        <h4 class="section-label">{node.label}</h4>
      {/if}
      {#each node.children ?? [] as child}
        <Self node={child} />
      {/each}
    </div>

  {:else if node.type === 'columns'}
    <div class="ambolt-columns {node.class ?? ''}"
         style={styleToString({ ...(node.style ?? {}), ...(node.gap ? { gap: node.gap } : {}) })}>
      {#each node.children ?? [] as child}
        <div class="ambolt-column">
          <Self node={child} />
        </div>
      {/each}
    </div>

  {:else if node.type === 'details'}
    <details class="ambolt-details {node.class ?? ''}"
             style={styleToString(node.style)}
             open={node.open ?? false}>
      <summary>{node.label}</summary>
      <div class="ambolt-details-content">
        {#each node.children ?? [] as child}
          <Self node={child} />
        {/each}
      </div>
    </details>

  {:else if node.type === 'view_switcher'}
    {#snippet viewContent(activeId)}
      {#each viewChildren(node.views, activeId) as child}
        <Self node={child} />
      {/each}
    {/snippet}
    {#snippet viewActions()}
      {#if node.actions}<Self node={node.actions} />{/if}
    {/snippet}
    <ViewSwitcher
      views={node.views ?? []}
      defaultView={node.default ?? node.views?.[0]?.id ?? ''}
      content={viewContent}
      actions={node.actions ? viewActions : undefined}
      class={node.class ?? ''}
      style={styleToString(node.style)}
    />

  {:else if node.type === 'stat_cards'}
    <StatCards endpoint={node.endpoint} cards={node.cards ?? []} class={node.class ?? ''} />

  {:else if node.type === 'data_table'}
    <DataTable
      endpoint={node.endpoint}
      columns={node.columns ?? null}
      pageSize={node.page_size ?? 0}
      searchable={node.searchable ?? false}
      selectable={node.selectable ?? false}
      refreshEvent={node.refresh_event ?? ''}
      class={node.class ?? ''}
    />

  {:else if node.type === 'create_button'}
    {#if node.href}
      <a href={node.href} class={buttonClass(node)}
         download={node.download ? true : undefined}
         style="text-decoration:none;display:inline-flex;align-items:center;gap:0.3rem;{styleToString(node.style)}">
        {#if node.icon}<i class="bi bi-{node.icon}"></i>{/if}
        {node.label}
      </a>
    {:else if node.modal}
      <button type="button" class={buttonClass(node)}
              onclick={(e) => openModal(e, node.modal, node.modal_size)}
              style={styleToString(node.style)}>
        {#if node.icon}<i class="bi bi-{node.icon}"></i>{/if}
        {node.label}
      </button>
    {:else if node.navigate}
      <button type="button" class={buttonClass(node)}
              onclick={() => { window.location.hash = '#/' + node.navigate; }}
              style={styleToString(node.style)}>
        {#if node.icon}<i class="bi bi-{node.icon}"></i>{/if}
        {node.label}
      </button>
    {:else}
      <button type="button" class={buttonClass(node)} style={styleToString(node.style)}>
        {#if node.icon}<i class="bi bi-{node.icon}"></i>{/if}
        {node.label}
      </button>
    {/if}

  {:else if node.type === 'html_block'}
    {#if node.class || node.style}
      <div class={node.class ?? ''} style={styleToString(node.style)}>
        {@html node.html ?? ''}
      </div>
    {:else}
      {@html node.html ?? ''}
    {/if}

  {:else}
    <!-- RenderNode: unknown node type "{node.type}" -->
  {/if}
{/if}
