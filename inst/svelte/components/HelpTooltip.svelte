<script>
  // HelpTooltip — Inline help icon with hover tooltip
  //
  // Shared component used by input components that support the `help` prop.
  // Renders a "?" icon after the label that shows tooltip text on hover.
  //
  // Props:
  //   text — the help text to display in the tooltip

  let { text = '' } = $props();
</script>

{#if text}
  <span class="help-tooltip"><span class="help-icon">?</span><span class="help-text">{text}</span></span>
{/if}

<style>
  .help-tooltip {
    position: relative;
    cursor: help;
  }
  .help-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 1.2rem;
    height: 1.2rem;
    font-size: 0.85rem;
    color: #9ca3af;
    cursor: help;
    vertical-align: middle;
  }
  .help-text {
    display: none;
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    top: 1.5rem;
    width: 220px;
    padding: 0.5rem 0.7rem;
    background: #1f2937;
    color: white;
    font-size: 0.8rem;
    font-weight: 400;
    line-height: 1.4;
    border-radius: 6px;
    z-index: 10;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  }
  .help-tooltip:hover .help-text {
    display: block;
  }
</style>
