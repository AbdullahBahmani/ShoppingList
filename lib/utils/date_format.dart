import '../models/shopping_list.dart';

/// Short, scannable date label: "Just now", "3h ago", "12 Mar".
String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return '${date.day} ${_month(date.month)}';
}

String _month(int month) => const [
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
][month - 1];

/// Groups lists by year, newest year first, for archive section headers.
Map<int, List<ShoppingList>> groupByYear(List<ShoppingList> lists) {
  final grouped = <int, List<ShoppingList>>{};
  for (final list in lists) {
    grouped.putIfAbsent(list.updatedAt.year, () => []).add(list);
  }

  final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final key in keys) key: grouped[key]!};
}
