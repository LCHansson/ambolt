<script>
  // AuthGuard — Wraps an ambolt app with authentication
  //
  // On mount, checks for an existing session via GET /api/auth/me
  // (browser sends HttpOnly cookie automatically). Shows LoginPage
  // when unauthenticated, app content when authenticated.
  //
  // Props:
  //   loginTitle — title shown on login page
  //   children   — app content (rendered when authenticated)

  import { auth } from './authStore.svelte.js';
  import LoginPage from './LoginPage.svelte';

  let { loginTitle = 'Logga in', children } = $props();

  // Check session on mount
  $effect(() => {
    auth.checkSession();
  });
</script>

{#if auth.isLoading}
  <div class="ambolt-auth-loading">
    <p>Laddar...</p>
  </div>
{:else if auth.isAuthenticated}
  {@render children()}
{:else}
  <LoginPage title={loginTitle} />
{/if}

<style>
  .ambolt-auth-loading {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--ambolt-font, system-ui, sans-serif);
    color: #6b7280;
  }
</style>
