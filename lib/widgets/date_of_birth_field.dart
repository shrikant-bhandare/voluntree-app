import 'package:flutter/material.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `5 Mar 2008` — unambiguous across locales, unlike `05/03/2008`.
String formatDateOfBirth(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// A tappable field that opens a date picker for a date of birth.
class DateOfBirthField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;

  const DateOfBirthField({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Date of birth',
      fieldLabelText: 'Date of birth',
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Date of birth',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pick(context),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            labelText: 'Date of birth',
            hintText: 'Select your date of birth',
            errorText: errorText,
            prefixIcon: const Icon(Icons.cake_outlined),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            value == null ? '' : formatDateOfBirth(value!),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
