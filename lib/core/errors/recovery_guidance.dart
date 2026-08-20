/// The safe next action that presentation may offer after a failure.
enum RecoveryGuidance {
  correctInput,
  signInAgain,
  retrySafely,
  checkStatusBeforeRetry,
  contactResponsibleTeam,
  doNotRetry,
}
