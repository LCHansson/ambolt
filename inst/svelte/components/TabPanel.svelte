<script>
  // TabPanel — Tabbed container for organizing content into panels
  //
  // Shiny equivalent: tabsetPanel(tabPanel("Tab1", ...), tabPanel("Tab2", ...))
  //
  // Divergence from Shiny: In Shiny, tabs are declared as nested function calls
  // and tab switching can trigger server round-trips. Here, tabs are defined as
  // a data array and content is rendered via Svelte's snippet system. Tab switching
  // is purely client-side — instant, no server involved.
  //
  // Why: This is one of the key architectural wins. Shiny's tab switching can be
  // slow because the server may need to render tab content. Our tabs exist entirely
  // in the browser — the server is only contacted when tab content needs data.
  //
  // Usage:
  //   <TabPanel tabs={[
  //     { id: 'plot', label: 'Plot' },
  //     { id: 'data', label: 'Data' },
  //   ]} bind:activeTab={currentTab}>
  //     {#snippet tab(tabId)}
  //       {#if tabId === 'plot'}
  //         <PlotOutput ... />
  //       {:else if tabId === 'data'}
  //         <DataTable ... />
  //       {/if}
  //     {/snippet}
  //   </TabPanel>
  //
  // Props:
  //   tabs      — array of { id, label } objects defining the tabs
  //   activeTab — bind:activeTab for two-way binding (string, the active tab id)
  //   tab       — snippet that receives the active tabId and renders content

  let { tabs = [], activeTab = $bindable(''), tab } = $props();

  // Default to first tab if no activeTab specified
  $effect(() => {
    if (!activeTab && tabs.length > 0) {
      activeTab = tabs[0].id;
    }
  });
</script>

<div class="ambolt-tab-panel">
  <nav class="tab-bar">
    {#each tabs as t}
      <button
        class:active={activeTab === t.id}
        onclick={() => activeTab = t.id}
      >
        {t.label}
      </button>
    {/each}
  </nav>

  <div class="tab-content">
    {@render tab(activeTab)}
  </div>
</div>

<style>
  .ambolt-tab-panel {
    margin-bottom: 1rem;
  }
  .tab-bar {
    display: flex;
    gap: 0;
    border-bottom: 2px solid #d1d5db;
  }
  .tab-bar button {
    padding: 0.6rem 1.2rem;
    border: none;
    background: none;
    font-size: 1rem;
    cursor: pointer;
    color: #6b7280;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    transition: color 0.15s, border-color 0.15s;
  }
  .tab-bar button:hover {
    color: #374151;
  }
  .tab-bar button.active {
    color: #4f46e5;
    border-bottom-color: #4f46e5;
    font-weight: 600;
  }
  .tab-content {
    border: 1px solid #d1d5db;
    border-top: none;
    border-radius: 0 0 6px 6px;
    padding: 1.5rem;
    background: white;
    min-height: 200px;
  }
</style>
