/// A provider-neutral classification of an unsuccessful operation.
enum FailureCategory {
  access,
  authenticationSession,
  validation,
  connectivity,
  temporaryService,
  capacityQuota,
  conflictDuplicate,
  missingData,
  unexpected,
}
