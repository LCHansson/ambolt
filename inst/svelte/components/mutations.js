// mutations.js — Imperative data mutation utilities (POST/PUT/DELETE)
//
// Simple async functions for sending data to the server.
// Separate from fetchData.svelte.js which handles reactive output fetching.
//
// When a response includes an `emit` field, the event bus is notified
// so listening components (e.g., DataTables) can re-fetch their data.

import { events } from './eventBus.svelte.js';

/**
 * Handle the `emit` field in mutation responses.
 * If the response JSON contains `emit: "event:name"`, fires the event.
 */
function handleEmit(data) {
  if (data && data.emit) {
    events.emit(data.emit, data);
  }
  // Show toast notification if the response includes a message
  if (data && data.toast) {
    window.dispatchEvent(new CustomEvent('ambolt:toast', {
      detail: { message: data.toast, type: data.toast_type || 'success' }
    }));
  }
}

/**
 * Extract a user-friendly error message from a failed response.
 * Tries to parse JSON body for an `error` field; falls back to HTTP status.
 */
async function extractError(method, endpoint, res) {
  try {
    const data = await res.json();
    if (data && data.error) return new Error(data.error);
  } catch { /* body not JSON or empty — fall through */ }
  return new Error(`${method} ${endpoint} failed: HTTP ${res.status}`);
}

/**
 * POST JSON to an endpoint.
 * @param {string} endpoint - URL path (e.g., "/api/contacts")
 * @param {object} body - Data to send as JSON
 * @param {object} [options] - Optional { token } for auth
 * @returns {Promise<object>} Parsed JSON response
 */
export async function postData(endpoint, body, options = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (options.token) headers['Authorization'] = `Bearer ${options.token}`;

  const res = await fetch(endpoint, {
    method: 'POST',
    headers,
    body: JSON.stringify(body)
  });
  if (!res.ok) throw await extractError('POST', endpoint, res);
  const data = await res.json();
  handleEmit(data);
  return data;
}

/**
 * PUT JSON to an endpoint.
 * @param {string} endpoint - URL path (e.g., "/api/contacts/123")
 * @param {object} body - Data to send as JSON
 * @param {object} [options] - Optional { token } for auth
 * @returns {Promise<object>} Parsed JSON response
 */
export async function putData(endpoint, body, options = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (options.token) headers['Authorization'] = `Bearer ${options.token}`;

  const res = await fetch(endpoint, {
    method: 'PUT',
    headers,
    body: JSON.stringify(body)
  });
  if (!res.ok) throw await extractError('PUT', endpoint, res);
  const data = await res.json();
  handleEmit(data);
  return data;
}

/**
 * DELETE an endpoint.
 * @param {string} endpoint - URL path (e.g., "/api/contacts/123")
 * @param {object} [options] - Optional { token } for auth
 * @returns {Promise<object>} Parsed JSON response
 */
export async function deleteData(endpoint, options = {}) {
  const headers = {};
  if (options.token) headers['Authorization'] = `Bearer ${options.token}`;

  const res = await fetch(endpoint, {
    method: 'DELETE',
    headers
  });
  if (!res.ok) throw await extractError('DELETE', endpoint, res);
  const data = await res.json();
  handleEmit(data);
  return data;
}
