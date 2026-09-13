# Implementation Plan: Same-Title Absence and Permission Alert

**Date**: 2026-09-13  
**Spec**: [spec.md](spec.md)

## Summary

Add a server-authoritative staffing-conflict check to the existing leave and permission approval flow. Before the relevant manager confirms an approval, the client receives a scoped advisory warning for same-title employees with overlapping dates. An idempotent notification is also queued when the conflict enters that manager’s review scope.

## Technical Context

**Language/Version**: Dart/Flutter and Node.js CommonJS  
**Storage**: Existing `users`, `leaves`, `permissions`, and notification documents; an additive idempotency/audit record only if needed  
**Testing**: Flutter service tests and Node request/notification tests  
**Constraints**: Cairo date overlap, manager-scoped visibility, bounded queries, no change to request routing or attendance/payroll semantics

## Design

1. Introduce a small domain policy that normalizes a job title and determines Cairo-date overlap.
2. Add a bounded server operation that resolves conflicts only for the authenticated manager and only for requests presently in that manager’s approval scope.
3. Reuse the durable notification queue with a deterministic key based on manager, submitted request, conflicting request, and overlap date; retries cannot duplicate the alert.
4. Add an advisory confirmation panel to leave and permission approval surfaces. It displays the relevant employees, title, request types, and dates, then lets the authorized manager use the ordinary approve/reject action.
5. Keep all existing approval updates, notifications, leave balances, attendance reconciliation, and payroll logic unchanged.

## Rollback

Hide the advisory UI and disable the conflict operation/notification producer. Existing requests and ordinary approval flows continue unchanged; no historical data requires migration.
