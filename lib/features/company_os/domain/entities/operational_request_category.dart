/// The employee-facing category used to separate finance from IT/operations.
///
/// This is intentionally distinct from the persisted request type. The latter
/// is retained so existing approval plans continue to work unchanged.
enum OperationalRequestCategory { technical, financial }
