<script>
  // NavSidebar — Navigation sidebar for multi-page ambolt apps
  //
  // Renders icon-based navigation links. Syncs with URL hash for
  // browser back/forward support. On mobile (<768px), collapses to
  // a hidden panel with hamburger toggle.
  //
  // Props:
  //   pages       — array of { id, label, icon } objects
  //   currentPage — bindable string, the active page id
  //   title       — optional app title shown at top of sidebar
  //   user        — optional { name, username, is_admin } for user info
  //   onlogout    — optional logout callback

  let { pages = [], currentPage = $bindable(''), title = '', user = null, onlogout = null, notifications = $bindable({}), adminLinks = [] } = $props();
  // adminLinks: [{ endpoint: '/api/contacts/hidden', icon: 'eye-slash', label: 'Dolda kontakter', modal: 'contacts/hidden_admin', modalSize: 'lg', refreshEvent: 'contacts:updated' }]

  // Fetch overdue count — when logged in, every 30s, and on interaction changes
  let overdueCount = $state(0);
  $effect(() => {
    if (!user) return; // Don't fetch before login
    function fetchOverdue() {
      fetch('/api/overview/overdue-count')
        .then(r => r.ok ? r.json() : { count: 0 })
        .then(d => { overdueCount = d.count || 0; })
        .catch(() => {});
    }
    fetchOverdue();
    const interval = setInterval(fetchOverdue, 30000);
    // Also refresh when interactions change
    function onEvent(e) {
      if (e.detail && e.detail.event === 'interactions:updated') {
        setTimeout(fetchOverdue, 500); // slight delay for DB to update
      }
    }
    window.addEventListener('ambolt:event', onEvent);
    return () => { clearInterval(interval); window.removeEventListener('ambolt:event', onEvent); };
  });

  // Admin link counts (configurable via adminLinks prop)
  let adminCounts = $state({});
  $effect(() => {
    if (!user?.is_admin || adminLinks.length === 0) return;
    function fetchCounts() {
      adminLinks.forEach(link => {
        if (!link.endpoint) return;
        fetch(link.endpoint)
          .then(r => r.ok ? r.json() : [])
          .then(d => { adminCounts = { ...adminCounts, [link.endpoint]: Array.isArray(d) ? d.length : 0 }; })
          .catch(() => {});
      });
    }
    fetchCounts();
    const interval = setInterval(fetchCounts, 30000);
    function onEvent(e) {
      const evt = e.detail?.event;
      if (adminLinks.some(l => l.refreshEvent === evt)) setTimeout(fetchCounts, 500);
    }
    window.addEventListener('ambolt:event', onEvent);
    return () => { clearInterval(interval); window.removeEventListener('ambolt:event', onEvent); };
  });

  // Pending contact actions (persistent sidebar notifications)
  let pendingActions = $state([]);
  let nextActionId = 0;

  function addPendingAction(detail) {
    // Avoid duplicates for same contact+type
    const key = `${detail.contactId}-${detail.type}`;
    if (pendingActions.some(a => a.key === key)) return;
    pendingActions = [...pendingActions, {
      id: nextActionId++,
      key,
      contactName: detail.contactName || '',
      contactId: detail.contactId,
      party: detail.party || '',
      type: detail.type, // 'samtal' or 'utskick'
      modal: detail.modal
    }];
  }

  function dismissAction(id) {
    pendingActions = pendingActions.filter(a => a.id !== id);
  }

  let showPendingModal = $state(false);

  function actOnAction(action) {
    showPendingModal = false;
    // Append tf_member_id if the logged-in user has one
    let modalUrl = action.modal;
    if (user?.tf_member_id) {
      modalUrl += `&tf_member_ids=${user.tf_member_id}`;
    }
    // Small delay so modal system clears before opening the new one
    setTimeout(() => {
      window.dispatchEvent(new CustomEvent('ambolt:open-modal', {
        detail: { modal: modalUrl, size: 'lg' }
      }));
    }, 150);
    dismissAction(action.id);
  }

  $effect(() => {
    function handleContactAction(e) {
      addPendingAction(e.detail || {});
    }
    window.addEventListener('ambolt:contact-action', handleContactAction);
    return () => window.removeEventListener('ambolt:contact-action', handleContactAction);
  });

  let mobileOpen = $state(false);

  // Sync with URL hash on mount
  $effect(() => {
    function onHashChange() {
      const hash = window.location.hash.replace('#/', '').replace('#', '');
      if (hash && pages.some(p => p.id === hash)) {
        currentPage = hash;
      }
    }

    // Read initial hash
    onHashChange();

    // Default to first page if no hash match
    if (!currentPage && pages.length > 0) {
      currentPage = pages[0].id;
    }

    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  });

  // Update hash when currentPage changes (without triggering hashchange loop)
  $effect(() => {
    if (currentPage) {
      const expected = '#/' + currentPage;
      if (window.location.hash !== expected) {
        history.replaceState(null, '', expected);
      }
    }
  });

  function navigate(pageId) {
    currentPage = pageId;
    window.location.hash = '#/' + pageId;
    mobileOpen = false;
  }
</script>

<!-- Mobile hamburger button (visible only on narrow screens) -->
<button class="ambolt-hamburger" onclick={() => mobileOpen = true} aria-label="Öppna meny">
  <i class="bi bi-list"></i>
</button>

<!-- Overlay backdrop (mobile only, when open) -->
{#if mobileOpen}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="ambolt-nav-overlay" onclick={() => mobileOpen = false} onkeydown={() => {}}></div>
{/if}

<nav class="ambolt-nav-sidebar" class:mobile-open={mobileOpen}>
  <div class="ambolt-nav-top">
    {#if title}
      <div class="ambolt-nav-header">
        <span>{title}</span>
        <button class="ambolt-nav-close" onclick={() => mobileOpen = false} aria-label="Stäng meny">
          <i class="bi bi-x-lg"></i>
        </button>
      </div>
    {/if}
    {#each pages as page}
      <button
        class="ambolt-nav-link"
        class:active={currentPage === page.id}
        onclick={() => navigate(page.id)}
      >
        {#if page.icon}
          <i class="bi bi-{page.icon} ambolt-nav-icon"></i>
        {/if}
        <span>{page.label}</span>
      </button>
    {/each}
    {#if overdueCount > 0}
      <button class="ambolt-nav-alert" data-modal="overview/overdue" data-modal-size="lg" title="Försenade uppföljningar">
        <i class="bi bi-bell-fill"></i>
        <span class="alert-badge">{overdueCount}</span>
        <span class="alert-text">Försenade</span>
      </button>
    {/if}
    {#if pendingActions.length > 0}
      <button class="ambolt-nav-pending-badge" onclick={() => showPendingModal = true} title="Ny interaktion">
        <i class="bi bi-envelope-check"></i>
        <span class="alert-badge pending-badge">{pendingActions.length}</span>
        <span>Ny interaktion</span>
      </button>
    {/if}
  </div>
  {#if user}
    <div class="ambolt-nav-user">
      <div class="user-name">
        <i class="bi bi-person-circle"></i>
        <span>{user.name || user.username}</span>
      </div>
      {#if user.is_admin}
        <span class="user-badge">Admin</span>
      {/if}
      {#if user.is_admin}
        <button data-modal="account/user_admin" data-modal-size="lg" class="ambolt-nav-action">
          <i class="bi bi-people-fill"></i>
          <span>Hantera användare</span>
        </button>
        {#each adminLinks as alink}
          <button data-modal={alink.modal} data-modal-size={alink.modalSize || 'lg'} class="ambolt-nav-action">
            <i class="bi bi-{alink.icon || 'gear'}"></i>
            <span>{alink.label}{#if adminCounts[alink.endpoint] > 0} <span class="hidden-count-badge">{adminCounts[alink.endpoint]}</span>{/if}</span>
          </button>
        {/each}
      {/if}
      <button data-modal="account/change_password" data-modal-size="sm" class="ambolt-nav-action">
        <i class="bi bi-key"></i>
        <span>Byt lösenord</span>
      </button>
      {#if onlogout}
        <button class="ambolt-nav-logout" onclick={onlogout}>
          <i class="bi bi-box-arrow-right"></i>
          <span>Logga ut</span>
        </button>
      {/if}
    </div>
  {/if}
</nav>

<!-- Pending contact actions modal -->
{#if showPendingModal}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="pending-modal-backdrop" onclick={() => showPendingModal = false} onkeydown={() => {}}>
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="pending-modal" onclick={(e) => e.stopPropagation()} onkeydown={() => {}}>
      <div class="pending-modal-header">
        <i class="bi bi-envelope-check"></i>
        <span>Ny interaktion</span>
        <button class="pending-modal-close" onclick={() => showPendingModal = false}>&times;</button>
      </div>
      <div class="pending-modal-body">
        {#if pendingActions.length === 0}
          <p style="color:#6b7280;">Inga väntande kontakter att registrera.</p>
        {:else}
          {#each pendingActions as action (action.id)}
            <div class="pending-card">
              <p>Du har nyss <strong>{action.type === 'samtal' ? 'ringt' : 'mailat'}</strong> <strong>{action.contactName}</strong>{action.party ? ` (${action.party})` : ''}.</p>
              <p class="pending-card-sub">Vill du registrera detta som en interaktion?</p>
              <div class="pending-card-actions">
                <button class="pending-btn-register" onclick={() => actOnAction(action)}>
                  <i class="bi bi-check-lg"></i> Ja, registrera
                </button>
                <button class="pending-btn-dismiss" onclick={() => dismissAction(action.id)}>
                  Nej tack
                </button>
              </div>
            </div>
          {/each}
        {/if}
      </div>
      <div class="pending-modal-footer">
        <button class="pending-btn-close" onclick={() => showPendingModal = false}>Stäng</button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* ── Hamburger button (mobile only) ── */
  .ambolt-hamburger {
    display: none;
    position: fixed;
    top: 0.6rem;
    left: 0.6rem;
    z-index: 1001;
    background: var(--ambolt-nav-bg, #1f2937);
    color: white;
    border: none;
    border-radius: 6px;
    padding: 0.4rem 0.6rem;
    font-size: 1.3rem;
    cursor: pointer;
    line-height: 1;
  }

  /* ── Overlay backdrop (mobile only) ── */
  .ambolt-nav-overlay {
    display: none;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 999;
  }

  /* ── Sidebar ── */
  .ambolt-nav-sidebar {
    width: 220px;
    overflow-x: hidden;
    background: var(--ambolt-nav-bg, #1f2937);
    color: var(--ambolt-nav-color, #e5e7eb);
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--ambolt-nav-border, #374151);
    position: fixed;
    top: 0;
    left: 0;
    height: 100vh;
    z-index: 100;
    overflow-y: auto;
  }

  .ambolt-nav-top {
    flex: 1;
    padding: 1rem 0;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .ambolt-nav-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.5rem 1rem 1rem;
    font-size: 1.1rem;
    font-weight: 700;
    color: white;
    border-bottom: 1px solid var(--ambolt-nav-border, #374151);
    margin-bottom: 0.5rem;
  }

  .ambolt-nav-close {
    display: none;
    background: none;
    border: none;
    color: #9ca3af;
    font-size: 1.1rem;
    cursor: pointer;
    padding: 0.2rem;
  }
  .ambolt-nav-close:hover { color: white; }

  .ambolt-nav-link {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.6rem 1rem;
    color: var(--ambolt-nav-color, #e5e7eb);
    text-decoration: none;
    font-size: 0.95rem;
    cursor: pointer;
    border: none;
    background: none;
    width: 100%;
    text-align: left;
    transition: background 0.15s, color 0.15s;
  }
  .ambolt-nav-link:hover {
    background: var(--ambolt-nav-hover-bg, rgba(255,255,255,0.1));
    color: white;
  }
  .ambolt-nav-link.active {
    background: var(--ambolt-nav-active-bg, var(--ambolt-primary, #4f46e5));
    color: white;
    font-weight: 600;
  }
  .ambolt-nav-icon {
    font-size: 1.1rem;
    width: 1.2rem;
    text-align: center;
  }

  /* ── User info section (pushed to bottom) ── */
  .ambolt-nav-user {
    padding: 0.75rem 1rem;
    border-top: 1px solid var(--ambolt-nav-border, #374151);
    font-size: 0.85rem;
  }
  .user-name {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: #d1d5db;
    margin-bottom: 0.25rem;
  }
  .user-badge {
    display: inline-block;
    padding: 0.1rem 0.4rem;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: 600;
    background: rgba(255, 255, 255, 0.15);
    color: #e5e7eb;
    margin-left: 1.6rem;
    margin-bottom: 0.35rem;
  }
  .ambolt-nav-alert {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    margin-top: 0.5rem;
    background: rgba(113, 0, 73, 0.15);
    border: none;
    border-radius: 4px;
    margin-left: 0.5rem;
    margin-right: 0.5rem;
    color: #fecdd3;
    font-size: 0.85rem;
    cursor: pointer;
    transition: background 0.15s;
    width: calc(100% - 1rem);
  }
  .ambolt-nav-alert:hover {
    background: rgba(113, 0, 73, 0.25);
  }
  .alert-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 1.2rem;
    height: 1.2rem;
    border-radius: 50%;
    background: #710049;
    color: white;
    font-size: 0.7rem;
    font-weight: 700;
  }
  .alert-text {
    font-size: 0.8rem;
  }
  .ambolt-nav-pending-badge {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    margin-top: 0.5rem;
    background: rgba(61, 183, 228, 0.15);
    border: none;
    border-radius: 4px;
    margin-left: 0.5rem;
    margin-right: 0.5rem;
    color: #93c5fd;
    font-size: 0.85rem;
    cursor: pointer;
    transition: background 0.15s;
    width: calc(100% - 1rem);
  }
  .ambolt-nav-pending-badge:hover {
    background: rgba(61, 183, 228, 0.25);
  }
  .pending-badge {
    background: #3DB7E4;
  }
  .hidden-count-badge {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 1rem;
    height: 1rem;
    border-radius: 50%;
    background: #710049;
    color: white;
    font-size: 0.65rem;
    font-weight: 700;
    margin-left: 0.3rem;
    vertical-align: middle;
  }

  /* ── Pending modal ── */
  .pending-modal-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.4);
    z-index: 3000;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .pending-modal {
    background: white;
    border-radius: 8px;
    width: min(90vw, 500px);
    max-height: 80vh;
    overflow-y: auto;
    box-shadow: 0 8px 32px rgba(0,0,0,0.2);
    font-family: var(--ambolt-font, system-ui, sans-serif);
  }
  .pending-modal-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 1rem 1.25rem;
    border-bottom: 1px solid #e5e7eb;
    font-size: 1.1rem;
    font-weight: 600;
    color: #1f2937;
  }
  .pending-modal-close {
    margin-left: auto;
    background: none;
    border: none;
    font-size: 1.3rem;
    cursor: pointer;
    color: #9ca3af;
    line-height: 1;
  }
  .pending-modal-close:hover { color: #374151; }
  .pending-modal-body {
    padding: 1rem 1.25rem;
  }
  .pending-card {
    border-left: 4px solid #3DB7E4;
    padding: 0.75rem 1rem;
    margin-bottom: 0.75rem;
    background: #f9fafb;
    border-radius: 0 6px 6px 0;
  }
  .pending-card p { margin: 0 0 0.3rem; font-size: 0.9rem; color: #374151; }
  .pending-card-sub { color: #6b7280 !important; font-size: 0.85rem !important; margin-bottom: 0.6rem !important; }
  .pending-card-actions {
    display: flex;
    gap: 0.5rem;
  }
  .pending-btn-register {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    padding: 0.3rem 0.7rem;
    border: none;
    border-radius: 4px;
    background: #15803d;
    color: white;
    font-size: 0.8rem;
    cursor: pointer;
  }
  .pending-btn-register:hover { background: #166534; }
  .pending-btn-dismiss {
    padding: 0.3rem 0.7rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    color: #6b7280;
    font-size: 0.8rem;
    cursor: pointer;
  }
  .pending-btn-dismiss:hover { background: #f3f4f6; }
  .pending-modal-footer {
    padding: 0.75rem 1.25rem;
    border-top: 1px solid #e5e7eb;
    text-align: right;
  }
  .pending-btn-close {
    padding: 0.3rem 0.8rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    background: white;
    color: #374151;
    font-size: 0.85rem;
    cursor: pointer;
  }
  .pending-btn-close:hover { background: #f3f4f6; }
  .ambolt-nav-action {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    background: none;
    border: none;
    width: 100%;
    text-align: left;
    padding: 0.3rem 0;
    color: #9ca3af;
    font-size: 0.8rem;
    text-decoration: none;
    cursor: pointer;
    transition: color 0.15s;
  }
  .ambolt-nav-action:hover {
    color: #d1d5db;
  }
  .ambolt-nav-logout {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.4rem 0;
    margin-top: 0.25rem;
    color: #9ca3af;
    font-size: 0.8rem;
    cursor: pointer;
    border: none;
    background: none;
    transition: color 0.15s;
  }
  .ambolt-nav-logout:hover {
    color: #f87171;
  }

  /* ── Mobile: collapsed sidebar ── */
  @media (max-width: 768px) {
    .ambolt-hamburger {
      display: block;
    }
    .ambolt-nav-overlay {
      display: block;
    }
    .ambolt-nav-sidebar {
      transform: translateX(-100%);
      transition: transform 0.25s ease;
      z-index: 1000;
    }
    .ambolt-nav-sidebar.mobile-open {
      transform: translateX(0);
    }
    .ambolt-nav-close {
      display: block;
    }
    .ambolt-nav-header {
      justify-content: center;
      text-align: center;
    }
  }
</style>
