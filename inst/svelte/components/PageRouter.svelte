<script>
  // PageRouter — Renders the active page in a multi-page ambolt app
  //
  // Each page is rendered as a div. Only the active page is visible.
  // Pages are kept mounted after first visit (lazy mount) so state is preserved.
  //
  // Props:
  //   pages       — array of { id, label } objects
  //   currentPage — string, the active page id
  //   page        — snippet that receives (pageId) and renders page content

  let { pages = [], currentPage = '', page } = $props();

  // Track which pages have been visited (for lazy mounting).
  // Use a plain array instead of Set — Svelte 5 tracks array mutations reactively.
  let visited = $state([]);

  let prevPage = $state('');

  $effect(() => {
    if (currentPage && !visited.includes(currentPage)) {
      visited = [...visited, currentPage];
    }
    // Dispatch page lifecycle events
    if (currentPage && currentPage !== prevPage) {
      if (prevPage) {
        window.dispatchEvent(new CustomEvent('ambolt:page-exit', {
          detail: { page: prevPage }
        }));
      }
      // Small delay to ensure DOM is rendered before page-enter scripts run
      setTimeout(() => {
        window.dispatchEvent(new CustomEvent('ambolt:page-enter', {
          detail: { page: currentPage }
        }));
      }, 50);
      prevPage = currentPage;
    }
  });
</script>

<div class="ambolt-page-content">
  {#each pages as p}
    {#if visited.includes(p.id)}
      <div class="ambolt-page" class:active={currentPage === p.id}>
        {@render page(p.id)}
      </div>
    {/if}
  {/each}
</div>

<style>
  .ambolt-page-content {
    padding: var(--ambolt-page-padding, 2rem);
    max-width: var(--ambolt-page-max-width, 1400px);
    font-family: var(--ambolt-font, system-ui, sans-serif);
  }
  .ambolt-page {
    display: none;
  }
  .ambolt-page.active {
    display: block;
  }
  @media (max-width: 768px) {
    .ambolt-page-content { padding: 1rem; }
  }
</style>
