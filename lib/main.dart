import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinApp());
}

class FinApp extends StatelessWidget {
  const FinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestor Financeiro Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          primary: const Color(0xFF00897B),
        ),
        useMaterial3: true,
      ),
      home: const FinanceHomeScreen(),
    );
  }
}

// ----------------- MODELO DE CONTA (COM SERIALIZAÇÃO JSON) -----------------
class Expense {
  String id;
  String title;
  double amount;
  DateTime dueDate;
  bool isPaid;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'isPaid': isPaid,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate']),
      isPaid: map['isPaid'] ?? false,
    );
  }
}

// ----------------- TELA PRINCIPAL -----------------
class FinanceHomeScreen extends StatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  State<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends State<FinanceHomeScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpensesFromStorage();
  }

  // Carregar dados salvos na memória offline
  Future<void> _loadExpensesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? expensesJson = prefs.getString('saved_expenses');

    if (expensesJson != null && expensesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(expensesJson);
        setState(() {
          _expenses = decodedList.map((item) => Expense.fromMap(item)).toList();
          _sortExpenses();
        });
      } catch (e) {
        debugPrint('Erro ao carregar dados: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  // Salvar dados no armazenamento offline
  Future<void> _saveExpensesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_expenses.map((e) => e.toMap()).toList());
    await prefs.setString('saved_expenses', encodedData);
  }

  void _sortExpenses() {
    _expenses.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  void _addExpense(String title, double amount, DateTime dueDate) {
    setState(() {
      _expenses.add(
        Expense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          dueDate: dueDate,
        ),
      );
      _sortExpenses();
    });
    _saveExpensesToStorage();
  }

  void _togglePaid(int index) {
    setState(() {
      _expenses[index].isPaid = !_expenses[index].isPaid;
    });
    _saveExpensesToStorage();
  }

  void _deleteExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
    _saveExpensesToStorage();
  }

  // Métricas financeiras calculadas dinamicamente
  double get _totalExpenses => _expenses.fold(0.0, (sum, item) => sum + item.amount);
  double get _totalPaid => _expenses.where((e) => e.isPaid).fold(0.0, (sum, item) => sum + item.amount);
  double get _totalPending => _totalExpenses - _totalPaid;
  double get _dailyGoal => _totalPending > 0 ? _totalPending / 30 : 0.0;

  void _showAddExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 5));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nova Despesa',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Descrição da Conta',
                  hintText: 'Ex: Financiamento, Internet, Luz',
                  prefixIcon: const Icon(Icons.receipt_long),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: r'Valor (R$)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.calendar_month, color: Color(0xFF00897B)),
                  title: const Text('Data de Vencimento'),
                  subtitle: Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('Alterar'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final text = titleController.text.trim();
                  final value = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;

                  if (text.isNotEmpty && value > 0) {
                    _addExpense(text, value, selectedDate);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Salvar Despesa', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Gestão de Despesas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Painel de Metas e Totais
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: [
                          const Text('Total Geral de Contas', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'R\$ ${_totalExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                          const Divider(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SummaryItem(
                                label: 'Pago (OK)',
                                amount: _totalPaid,
                                color: Colors.green.shade700,
                                icon: Icons.check_circle_outline,
                              ),
                              _SummaryItem(
                                label: 'Pendente',
                                amount: _totalPending,
                                color: Colors.redAccent,
                                icon: Icons.pending_actions,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Card da Meta Diária
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings, color: Color(0xFF00897B), size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Meta Diária (Base: 30 dias)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                                      ),
                                      Text(
                                        'R\$ ${_dailyGoal.toStringAsFixed(2)} / dia para quitar',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Lista de Contas Cadastradas
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma conta cadastrada.\nToque no botão abaixo para adicionar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _expenses.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final item = _expenses[index];
                            final isOverdue = !item.isPaid &&
                                item.dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: item.isPaid
                                      ? Colors.green.shade300
                                      : (isOverdue ? Colors.red.shade300 : Colors.transparent),
                                  width: 1.5,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: IconButton(
                                  icon: Icon(
                                    item.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: item.isPaid ? Colors.green : Colors.grey,
                                    size: 30,
                                  ),
                                  onPressed: () => _togglePaid(index),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                                    color: item.isPaid ? Colors.grey : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Vencimento: ${item.dueDate.day.toString().padLeft(2, '0')}/${item.dueDate.month.toString().padLeft(2, '0')}/${item.dueDate.year}',
                                      style: TextStyle(
                                        color: isOverdue ? Colors.red : Colors.grey.shade700,
                                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      item.isPaid ? 'Pago' : (isOverdue ? 'Atrasado' : 'Pendente'),
                                      style: TextStyle(
                                        color: item.isPaid
                                            ? Colors.green
                                            : (isOverdue ? Colors.red : Colors.orange.shade800),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${item.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: item.isPaid ? Colors.grey : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                      onPressed: () => _deleteExpense(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        onPressed: _showAddExpenseModal,
        icon: const Icon(Icons.add),
        label: const Text('Nova Despesa'),
      ),
    );
  }
}

// ----------------- SUB-WIDGET DE RESUMO -----------------
class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              'R\$ ${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ],
    );
  }
}
