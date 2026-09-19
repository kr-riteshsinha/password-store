/// Shortest passcode accepted when setting or resetting the vault passcode.
const minPasscodeLength = 4;

/// Validates a new passcode and its confirmation. Returns an error message to
/// show the user, or null when the passcode can be used.
String? newPasscodeError(String passcode, String confirmation) {
  if (passcode.trim().isEmpty) return 'Please enter a passcode';
  if (passcode.trim().length < minPasscodeLength) {
    return 'Passcode must be at least $minPasscodeLength characters';
  }
  if (passcode != confirmation) return "Passcodes don't match";
  return null;
}
