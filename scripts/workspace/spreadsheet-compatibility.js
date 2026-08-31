const READ_ONLY_COMPATIBILITIES = new Set([
  'protectedReadOnly',
  'unsupportedReadOnly',
]);

function workspaceSheetCompatibility(resource) {
  const value = String(resource?.compatibility || '').trim();
  return READ_ONLY_COMPATIBILITIES.has(value) ? value : 'fullyEditable';
}

/// Provider mutations must never be attempted for content intentionally
/// classified as protected or unsupported. The UI may still render the safe
/// bounded viewport in read-only mode.
function ensureWorkspaceSheetCompatible(resource) {
  if (workspaceSheetCompatibility(resource) === 'fullyEditable') return;
  const error = new Error('This spreadsheet content is read only.');
  error.code = 'unsupported';
  error.statusCode = 409;
  throw error;
}

module.exports = { workspaceSheetCompatibility, ensureWorkspaceSheetCompatible };
