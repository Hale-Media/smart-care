class Validators {
  Validators._();

  static String? required(String? v, [String field = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.\-]+@[\w\-]+\.[\w.\-]+$');
    if (!re.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  static String? nhsNumber(String? v) {
    if (v == null || v.isEmpty) return null; // optional
    final digits = v.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return 'NHS number must be 10 digits';
    }
    return null;
  }
}
