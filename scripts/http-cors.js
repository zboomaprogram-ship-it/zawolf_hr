'use strict';

// Keep privileged operation headers explicit. Browsers preflight these headers
// before sending an authenticated mutation to the Hostinger integration API.
const operationCorsHeaders = Object.freeze([
  'Authorization',
  'Content-Type',
  'X-Operation-Id',
]);

function operationCorsHeaderValue() {
  return operationCorsHeaders.join(', ');
}

module.exports = {
  operationCorsHeaders,
  operationCorsHeaderValue,
};
