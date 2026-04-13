// authStore.js — Reactive auth state for ambolt apps
//
// Manages authentication state (user, loading, errors).
// Does NOT manage cookies or tokens — cookies are HttpOnly and
// handled entirely by the browser + server.
//
// Usage in components:
//   import { auth } from 'ambolt';
//   {#if auth.isAuthenticated} ... {/if}

let user = $state(null);
let isLoading = $state(true);
let error = $state(null);
let isAuthenticated = $derived(user !== null);

async function checkSession() {
  isLoading = true;
  error = null;
  try {
    const res = await fetch('/api/auth/me');
    if (res.ok) {
      const data = await res.json();
      user = data.user;
    } else {
      user = null;
    }
  } catch (e) {
    user = null;
  }
  isLoading = false;
}

async function login(username, password) {
  error = null;
  const res = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password })
  });
  const data = await res.json();
  if (data.success) {
    user = data.user;
    return true;
  } else {
    error = data.error || 'Inloggningen misslyckades';
    return false;
  }
}

async function logout() {
  await fetch('/api/auth/logout', { method: 'POST' });
  user = null;
}

export const auth = {
  get user() { return user; },
  get isAuthenticated() { return isAuthenticated; },
  get isLoading() { return isLoading; },
  get error() { return error; },
  checkSession,
  login,
  logout
};
