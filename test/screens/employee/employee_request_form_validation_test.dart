import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final requestScreen =
      File('lib/screens/employee/employee_requests.dart').readAsStringSync();
  final themeFile = File('lib/theme/theme.dart').readAsStringSync();
  final wolfInputField =
      File('lib/components/wolf_input_field.dart').readAsStringSync();

  group('Employee Request Form Validation and Error Visibility Tests', () {
    test('theme inputDecorationTheme defines focusedErrorBorder and multi-line errorStyle', () {
      expect(themeFile, contains('focusedErrorBorder: OutlineInputBorder('));
      expect(themeFile, contains('errorStyle: GoogleFonts.ibmPlexSansArabic('));
      expect(themeFile, contains('errorMaxLines: 3'));
    });

    test('WolfInputField supports autovalidateMode and errorMaxLines', () {
      expect(wolfInputField, contains('final AutovalidateMode? autovalidateMode;'));
      expect(wolfInputField, contains('autovalidateMode: widget.autovalidateMode,'));
      expect(wolfInputField, contains('errorMaxLines: 3,'));
    });

    test('employee_requests.dart attaches _submitScrollController to the console', () {
      expect(requestScreen, contains('final ScrollController _submitScrollController = ScrollController();'));
      expect(requestScreen, contains('controller: _submitScrollController,'));
      expect(requestScreen, contains('_submitScrollController.dispose();'));
    });

    test('employee_requests.dart defines _onValidationFailed with auto-scroll and SnackBar', () {
      expect(requestScreen, contains('void _onValidationFailed({String? customMessage})'));
      expect(requestScreen, contains('_submitScrollController.animateTo('));
      expect(requestScreen, contains('_autoValidate = true;'));
      expect(requestScreen, contains('SnackBarBehavior.floating'));
    });

    test('employee_requests.dart renders _buildSubmitButtonArea with inline error callout above submit button', () {
      expect(requestScreen, contains('Widget _buildSubmitButtonArea({'));
      expect(requestScreen, contains('if (_formErrorMessage != null)'));
      expect(requestScreen, contains('WolfButton('));
    });

    test('all 8 forms bind autovalidateMode to _autoValidate', () {
      expect(requestScreen, contains('key: _formKeyPermission,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyLeave,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyAdvance,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyComplaint,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyAttendanceCorrection,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyAdministrative,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyFieldMission,\n      autovalidateMode:\n          _autoValidate'));
      expect(requestScreen, contains('key: _formKeyResignation,\n      autovalidateMode:\n          _autoValidate'));
    });

    test('all submission handlers invoke _onValidationFailed on invalid fields', () {
      expect(requestScreen, contains('if (!_formKeyPermission.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyLeave.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyAdvance.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyComplaint.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyAttendanceCorrection.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyAdministrative.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyFieldMission.currentState!.validate()) {\n      _onValidationFailed();'));
      expect(requestScreen, contains('if (!_formKeyResignation.currentState!.validate()) {\n      _onValidationFailed();'));
    });
  });
}
