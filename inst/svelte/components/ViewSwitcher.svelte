<script>
  // ViewSwitcher — Toggle between multiple views of the same data
  //
  // Renders a button bar and conditionally shows the active view's content.
  // Used for card/table/ranking toggles, or any multi-view layout.
  //
  // Props:
  //   views       — array of { id, label, icon } definitions
  //   defaultView — id of the initially active view
  //   content     — snippet(activeView) for rendering view content
  //   actions     — optional snippet for right-side actions (e.g., export links)

  let { views = [], defaultView = '', content, actions, class: className = '', style: styleStr = '' } = $props();
  let activeView = $state('');
  $effect(() => {
    if (!activeView) activeView = defaultView || (views.length > 0 ? views[0].id : '');
  });
</script>

<div class="ambolt-view-switcher {className}" style={styleStr || undefined}>
  <div class="ambolt-view-bar">
    <div class="ambolt-view-buttons">
      {#each views as view}
        <button
          class="ambolt-view-btn"
          class:active={activeView === view.id}
          onclick={() => activeView = view.id}
          title={view.label}
        >
          {#if view.icon}<i class="bi bi-{view.icon}"></i>{/if}
          {#if view.label}<span class="ambolt-view-label">{view.label}</span>{/if}
        </button>
      {/each}
    </div>
    {#if actions}
      <div class="ambolt-view-actions">
        {@render actions()}
      </div>
    {/if}
  </div>
  <div class="ambolt-view-content">
    {@render content(activeView)}
  </div>
</div>

<style>
  .ambolt-view-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.75rem;
  }
  .ambolt-view-buttons {
    display: flex;
    gap: 0;
  }
  .ambolt-view-btn {
    padding: 0.35rem 0.7rem;
    border: 1px solid var(--ambolt-border, #d1d5db);
    font-size: 0.85rem;
    cursor: pointer;
    background: white;
    color: #374151;
    transition: background 0.15s, color 0.15s;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
  }
  .ambolt-view-btn:first-child {
    border-radius: var(--ambolt-radius-sm, 4px) 0 0 var(--ambolt-radius-sm, 4px);
  }
  .ambolt-view-btn:last-child {
    border-radius: 0 var(--ambolt-radius-sm, 4px) var(--ambolt-radius-sm, 4px) 0;
  }
  .ambolt-view-btn:not(:first-child) {
    border-left: none;
  }
  .ambolt-view-btn.active {
    background: var(--ambolt-primary, #006589);
    color: white;
    border-color: var(--ambolt-primary, #006589);
  }
  .ambolt-view-btn:not(.active):hover {
    background: #f3f4f6;
  }
  .ambolt-view-actions {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }
  @media (max-width: 480px) {
    .ambolt-view-bar {
      flex-wrap: wrap;
      gap: 0.5rem;
    }
    .ambolt-view-btn {
      font-size: 0.8rem;
      padding: 0.3rem 0.5rem;
    }
    .ambolt-view-actions {
      flex-wrap: wrap;
      gap: 0.3rem;
    }
  }
</style>
