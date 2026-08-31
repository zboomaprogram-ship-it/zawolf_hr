function validatePageSize(rawValue, { fallback = 50, maximum = 100 } = {}) {
  const value = Number(rawValue || fallback);
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    const error = new Error('قيمة حجم الصفحة غير صالحة.');
    error.code = 'validation';
    throw error;
  }
  return value;
}

function validateParentResourceId(value) {
  if (value == null || value === '') return null;
  const id = String(value);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) {
    const error = new Error('معرّف المجلد غير صالح.');
    error.code = 'validation';
    throw error;
  }
  return id;
}

module.exports = { validatePageSize, validateParentResourceId };
