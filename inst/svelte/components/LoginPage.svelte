<script>
  // LoginPage — Themed login form for ambolt apps
  //
  // Handles username/password submission via POST /api/auth/login.
  // Cookie is set server-side (HttpOnly) — no JS cookie manipulation.
  //
  // Props:
  //   title    — heading text (e.g., "Val26 Kontakthantering")
  //   onLogin  — callback when login succeeds (receives user data)

  import { auth } from './authStore.svelte.js';

  let { title = 'Logga in', onLogin = () => {} } = $props();

  let username = $state('');
  let password = $state('');
  let submitting = $state(false);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!username.trim() || !password) return;
    submitting = true;
    const success = await auth.login(username, password);
    submitting = false;
    if (success) {
      password = '';
      onLogin(auth.user);
    }
  }
</script>

<div class="ambolt-login-page">
  <form class="ambolt-login-form" onsubmit={handleSubmit}>
    <h1 class="ambolt-login-title">{title}</h1>

    {#if auth.error}
      <div class="ambolt-login-error">{auth.error}</div>
    {/if}

    <label class="ambolt-login-label">
      Användarnamn
      <input
        type="text"
        bind:value={username}
        autocomplete="username"
        disabled={submitting}
        class="ambolt-login-input"
      />
    </label>

    <label class="ambolt-login-label">
      Lösenord
      <input
        type="password"
        bind:value={password}
        autocomplete="current-password"
        disabled={submitting}
        class="ambolt-login-input"
      />
    </label>

    <button
      type="submit"
      disabled={submitting || !username.trim() || !password}
      class="ambolt-login-button"
    >
      {submitting ? 'Loggar in...' : 'Logga in'}
    </button>
  </form>
</div>

<style>
  .ambolt-login-page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f3f4f6;
    font-family: var(--ambolt-font, system-ui, sans-serif);
  }
  .ambolt-login-form {
    background: white;
    padding: 2.5rem;
    border-radius: 8px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);
    width: 100%;
    max-width: 380px;
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }
  .ambolt-login-title {
    margin: 0 0 0.5rem;
    font-size: 1.5rem;
    font-weight: 700;
    color: #1f2937;
    text-align: center;
  }
  .ambolt-login-error {
    background: #fef2f2;
    color: #991b1b;
    border: 1px solid #fecaca;
    border-radius: 6px;
    padding: 0.6rem 0.8rem;
    font-size: 0.9rem;
  }
  .ambolt-login-label {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    font-size: 0.9rem;
    font-weight: 500;
    color: #374151;
  }
  .ambolt-login-input {
    padding: 0.6rem 0.75rem;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    font-size: 1rem;
    outline: none;
    transition: border-color 0.15s;
  }
  .ambolt-login-input:focus {
    border-color: var(--ambolt-primary, #4f46e5);
    box-shadow: 0 0 0 3px var(--ambolt-primary-focus, rgba(79, 70, 229, 0.15));
  }
  .ambolt-login-input:disabled {
    background: #f9fafb;
  }
  .ambolt-login-button {
    padding: 0.7rem;
    background: var(--ambolt-primary, #4f46e5);
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .ambolt-login-button:hover:not(:disabled) {
    background: var(--ambolt-primary-hover, #4338ca);
  }
  .ambolt-login-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style>
