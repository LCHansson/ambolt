<script>
  // FormBody — Renders a form from server-provided field definitions
  //
  // Used inside Modal when the render function returns { fields, submit }
  // instead of { html }. Each field maps to an existing input component
  // type (text, textarea, select, numeric, date, checkbox).
  //
  // Props:
  //   fields    — array of { id, type, label, value, required, choices, ... }
  //   submit    — { endpoint, method, emit, label }
  //   onSuccess — callback after successful submit (closes modal)

  import { postData, putData, deleteData } from './mutations.js';
  import SearchSelect from './SearchSelect.svelte';
  import CheckboxGroupInput from './CheckboxGroupInput.svelte';
  import flatpickr from 'flatpickr';
  import 'flatpickr/dist/flatpickr.min.css';
  import { Swedish } from 'flatpickr/dist/l10n/sv.js';

  let { fields = [], submit = {}, onSuccess = undefined } = $props();

  // Svelte action: initialize flatpickr on date inputs
  function initFlatpickr(node, fieldId) {
    const fp = flatpickr(node, {
      locale: Swedish,
      dateFormat: 'Y-m-d',
      defaultDate: formData[fieldId] || null,
      allowInput: true,
      onChange: (selectedDates, dateStr) => {
        formData[fieldId] = dateStr;
      }
    });
    return {
      destroy() { fp.destroy(); }
    };
  }

  // Initialize form data from field defaults
  let formData = $state({});
  let errors = $state({});
  let serverError = $state('');
  let submitting = $state(false);

  $effect(() => {
    const initial = {};
    for (const f of fields) {
      if (f.type === 'checkboxgroup') {
        initial[f.id] = f.value ?? [];
      } else if (f.type === 'multiselect') {
        initial[f.id] = f.value ?? [];
      } else {
        initial[f.id] = f.value ?? (f.type === 'checkbox' ? false : '');
      }
    }
    formData = initial;
    errors = {};
    serverError = '';
  });

  function validate() {
    const newErrors = {};
    for (const f of fields) {
      if (f.required && f.type !== 'hidden') {
        const val = formData[f.id];
        if (val === '' || val === null || val === undefined) {
          newErrors[f.id] = 'Obligatoriskt fält';
        }
      }
    }
    errors = newErrors;
    return Object.keys(newErrors).length === 0;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!validate()) return;

    submitting = true;
    serverError = '';

    try {
      const method = (submit.method || 'POST').toUpperCase();
      const endpoint = submit.endpoint || '';

      if (method === 'DELETE') {
        await deleteData(endpoint);
      } else if (method === 'PUT') {
        await putData(endpoint, formData);
      } else {
        await postData(endpoint, formData);
      }

      if (onSuccess) onSuccess();
    } catch (err) {
      serverError = err.message || 'Ett fel uppstod';
    } finally {
      submitting = false;
    }
  }
</script>

<form class="ambolt-form" onsubmit={handleSubmit}>
  {#if serverError}
    <div class="form-error-banner">{serverError}</div>
  {/if}

  {#each fields as field}
    {#if field.type === 'hidden'}
      <!-- hidden fields are included in formData but not rendered -->
    {:else}
      <div class="form-field" class:has-error={errors[field.id]}>
        {#if field.type === 'checkbox'}
          <label class="form-checkbox-label">
            <input type="checkbox" bind:checked={formData[field.id]} />
            {field.label || ''}
            {#if field.required}<span class="required">*</span>{/if}
          </label>
        {:else}
          <label for={field.id}>
            {field.label || ''}
            {#if field.required}<span class="required">*</span>{/if}
          </label>

          {#if field.type === 'text' || field.type === 'password'}
            <input
              type={field.type === 'password' ? 'password' : 'text'}
              id={field.id}
              bind:value={formData[field.id]}
              placeholder={field.placeholder || ''}
            />
          {:else if field.type === 'textarea'}
            <textarea
              id={field.id}
              bind:value={formData[field.id]}
              placeholder={field.placeholder || ''}
              rows={field.rows || 3}
            ></textarea>
          {:else if field.type === 'multiselect'}
            {#if Array.isArray(formData[field.id])}
              <SearchSelect
                id={field.id}
                choices={field.choices || []}
                bind:value={formData[field.id]}
                placeholder={field.placeholder || 'Sök...'}
              />
            {/if}
          {:else if field.type === 'checkboxgroup'}
            {#if Array.isArray(formData[field.id])}
              <CheckboxGroupInput
                id={field.id}
                label=""
                choices={field.choices || []}
                bind:selected={formData[field.id]}
              />
            {/if}
          {:else if field.type === 'select'}
            <select id={field.id} bind:value={formData[field.id]}>
              {#each (field.choices || []) as choice}
                {#if typeof choice === 'string'}
                  <option value={choice}>{choice}</option>
                {:else}
                  <option value={choice.value}>{choice.label}</option>
                {/if}
              {/each}
            </select>
          {:else if field.type === 'numeric'}
            <input
              type="number"
              id={field.id}
              bind:value={formData[field.id]}
              min={field.min}
              max={field.max}
              step={field.step || 1}
            />
          {:else if field.type === 'date'}
            <input
              type="text"
              id={field.id}
              placeholder="Välj datum..."
              value={formData[field.id] || ''}
              use:initFlatpickr={field.id}
            />
          {:else if field.type === 'time'}
            <input
              type="time"
              id={field.id}
              bind:value={formData[field.id]}
            />
          {:else}
            <input
              type="text"
              id={field.id}
              bind:value={formData[field.id]}
              placeholder={field.placeholder || ''}
            />
          {/if}
        {/if}

        {#if errors[field.id]}
          <span class="field-error">{errors[field.id]}</span>
        {/if}
      </div>
    {/if}
  {/each}

  <div class="form-actions">
    <button type="submit" class="form-submit" class:danger={submit.style === 'danger'} disabled={submitting}>
      {submitting ? 'Sparar...' : (submit.label || 'Spara')}
    </button>
  </div>
</form>

<style>
  .ambolt-form {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }
  .form-error-banner {
    background: #fef2f2;
    color: #dc2626;
    border: 1px solid #fecaca;
    border-radius: 4px;
    padding: 0.5rem 0.75rem;
    font-size: 0.9rem;
  }
  .form-field label {
    display: block;
    font-weight: 500;
    margin-bottom: 0.25rem;
    font-size: 0.95rem;
  }
  .form-field input[type="text"],
  .form-field input[type="password"],
  .form-field input[type="number"],
  .form-field input[type="time"],
  .form-field textarea,
  .form-field select {
    font-size: 1rem;
    padding: 0.35rem 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    width: 100%;
    box-sizing: border-box;
    font-family: inherit;
  }
  .form-field textarea {
    resize: vertical;
  }
  .form-field select {
    background: white;
  }
  .form-field :global(.flatpickr-input) {
    font-size: 1rem;
    padding: 0.35rem 0.5rem;
    border: 1px solid #d1d5db;
    border-radius: 4px;
    width: 100%;
    display: block;
  }
  .form-field.has-error input,
  .form-field.has-error textarea,
  .form-field.has-error select {
    border-color: #dc2626;
  }
  .required {
    color: #dc2626;
    margin-left: 0.15rem;
  }
  .field-error {
    color: #dc2626;
    font-size: 0.8rem;
    margin-top: 0.15rem;
    display: block;
  }
  .form-checkbox-label {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 500;
    font-size: 0.95rem;
    cursor: pointer;
  }
  .form-checkbox-label input[type="checkbox"] {
    width: 1.1rem;
    height: 1.1rem;
    cursor: pointer;
  }
  .form-actions {
    display: flex;
    justify-content: flex-end;
    padding-top: 0.5rem;
    border-top: 1px solid #e5e7eb;
    margin-top: 0.25rem;
  }
  .form-submit {
    padding: 0.5rem 1.25rem;
    background: var(--ambolt-primary, #4f46e5);
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 0.95rem;
    font-weight: 500;
    cursor: pointer;
  }
  .form-submit:hover:not(:disabled) {
    opacity: 0.9;
  }
  .form-submit:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .form-submit.danger {
    background: var(--ambolt-danger, #dc2626);
  }
</style>
