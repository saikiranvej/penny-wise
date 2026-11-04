
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const navy = Color(0xFF172554);
const blue = Color(0xFF3157D5);
const green = Color(0xFF159B72);
const red = Color(0xFFE35D6A);

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider()..load(),
      child: const PennyWiseApp(),
    ),
  );
}

class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'isIncome': isIncome,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        category: json['category'],
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'],
        date: DateTime.parse(json['date']),
      );
}

class ExpenseProvider extends ChangeNotifier {
  List<Expense> expenses = [];
  bool loading = true;
  String? error;

  double get income => expenses
      .where((e) => e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get totalExpenses => expenses
      .where((e) => !e.isIncome)
      .fold(0, (sum, e) => sum + e.amount);

  double get balance => income - totalExpenses;

  String money(double value) => '₹${value.toStringAsFixed(2)}';

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pennywise_expenses');

      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        expenses = decoded
            .map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      error = 'Could not load transactions. Please retry.';
    }

    loading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pennywise_expenses',
      jsonEncode(expenses.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(Expense expense) async {
    expenses.insert(0, expense);
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }
}

class PennyWiseApp extends StatelessWidget {
  const PennyWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PennyWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FB),
          foregroundColor: navy,
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    if (provider.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: provider.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const AddExpenseScreen(),
      const ReportsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: blue),
            SizedBox(width: 10),
            Text('PennyWise',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Transactions'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), label: 'Add'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline), label: 'Reports'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [navy, blue]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TOTAL BALANCE',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(p.money(p.balance),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _amountInfo('Income', p.income, green),
                  ),
                  Expanded(
                    child: _amountInfo('Expenses', p.totalExpenses, red),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Recent transactions',
            style: TextStyle(
                color: navy, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (p.expenses.isEmpty)
          const EmptyMessage('No transactions yet. Add your first one.')
        else
          ...p.expenses.take(5).map(
                (e) => ExpenseTile(
                  expense: e,
                  onTap: () => openDetails(context, e),
                ),
              ),
      ],
    );
  }

  Widget _amountInfo(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 5),
        Text('₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: color, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();

    if (p.expenses.isEmpty) {
      return const EmptyMessage('No transactions recorded yet.');
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Transaction History',
            style: TextStyle(
                color: navy, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ...p.expenses.map(
          (e) => ExpenseTile(
            expense: e,
            onTap: () => openDetails(context, e),
          ),
        ),
      ],
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String category = 'Food';
  bool isIncome = false;
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;

    setState(() => saving = true);

    try {
      await context.read<ExpenseProvider>().add(
            Expense(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              title: titleController.text.trim(),
              category: category,
              amount: double.parse(amountController.text.trim()),
              isIncome: isIncome,
              date: date,
            ),
          );

      titleController.clear();
      amountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Add Transaction',
            style: TextStyle(
                color: navy, fontSize: 23, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Form(
          key: formKey,
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Expense')),
                  ButtonSegment(value: true, label: Text('Income')),
                ],
                selected: {isIncome},
                onSelectionChanged: (s) =>
                    setState(() => isIncome = s.first),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Transaction title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  'Food',
                  'Transport',
                  'Shopping',
                  'Bills',
                  'Health',
                  'Education',
                  'Salary',
                  'Other'
                ]
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => category = v ?? 'Other'),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                icon: const Icon(Icons.calendar_month),
                label: Text('${date.day}/${date.month}/${date.year}'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Save Transaction'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final totals = <String, double>{};

    for (final e in p.expenses.where((e) => !e.isIncome)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Reports & Analytics',
            style: TextStyle(
                color: navy, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _reportCard('Total Income', p.money(p.income), green),
        _reportCard('Total Expenses', p.money(p.totalExpenses), red),
        _reportCard('Remaining Balance', p.money(p.balance), blue),
        const SizedBox(height: 20),
        const Text('Expenses by category',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (totals.isEmpty)
          const EmptyMessage('Add expenses to see category reports.')
        else
          ...totals.entries.map(
            (e) => Card(
              child: ListTile(
                title: Text(e.key),
                trailing: Text(p.money(e.value),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reportCard(String title, String amount, Color color) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(amount,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
    );
  }
}

class ExpenseDetailsScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailsScreen({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final p = context.read<ExpenseProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Details')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                expense.isIncome
                    ? Icons.south_west
                    : Icons.north_east,
                size: 55,
                color: expense.isIncome ? green : red,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${expense.isIncome ? '+' : '-'}${p.money(expense.amount)}',
                style: const TextStyle(
                    fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),
            _detailRow('Title', expense.title),
            _detailRow('Category', expense.category),
            _detailRow('Type', expense.isIncome ? 'Income' : 'Expense'),
            _detailRow(
                'Date', '${expense.date.day}/${expense.date.month}/${expense.date.year}'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: red),
                onPressed: () async {
                  await p.delete(expense.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.blueGrey)),
      subtitle: Text(value,
          style: const TextStyle(
              color: navy, fontSize: 17, fontWeight: FontWeight.w600)),
    );
  }
}

void openDetails(BuildContext context, Expense expense) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ExpenseDetailsScreen(expense: expense),
    ),
  );
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = expense.isIncome ? green : red;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Icon(
            expense.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(expense.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${expense.category} • ${expense.date.day}/${expense.date.month}/${expense.date.year}'),
        trailing: Text(
          '${expense.isIncome ? '+' : '-'}₹${expense.amount.toStringAsFixed(2)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  final String message;

  const EmptyMessage(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 15)),
      ),
    );
  }
}
