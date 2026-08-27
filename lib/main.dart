import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

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
      home: const AuthScreen(),
    );
  }
}

// ----------------- MODELO DE DADOS -----------------
class Expense {
  String id;
  String title;
  double amount;
  DateTime dueDate;
  DateTime? reminderDateTime;
  bool isPaid;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.reminderDateTime,
    this.isPaid = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'isPaid': isPaid,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate']),
      reminderDateTime: map['reminderDateTime'] != null ? DateTime.parse(map['reminderDateTime']) : null,
      isPaid: map['isPaid'] ?? false,
    );
  }
}

// ----------------- TELA DE AUTENTICAÇÃO (LOGIN & BIOMETRIA) -----------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  Future<void> _initBiometrics() async {
    final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    setState(() => _canCheckBiometrics = canCheck);
  }

  Future<void> _authenticateBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Toque no sensor para acessar o app',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (authenticated && mounted) {
        _goToHome();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha na autenticação: $e')),
      );
    }
  }

  void _loginWithEmailPassword() {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    if (email.isNotEmpty && pass.isNotEmpty) {
      _goToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha e-mail e senha para entrar.')),
      );
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const FinanceHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFF00897B),
                child: Icon(Icons.account_balance_wallet, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Gestor Financeiro', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const Text('Acesso seguro e offline', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loginWithEmailPassword,
                  child: const Text('Entrar', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_canCheckBiometrics) ...[
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('OU')),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.fingerprint, size: 28),
                  label: const Text('Entrar com Biometria / Digital'),
                  onPressed: _authenticateBiometrics,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------- TELA PRINCIPAL (DASHBOARD & DESPESAS) -----------------
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
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('saved_expenses');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _expenses = decoded.map((i) => Expense.fromMap(i)).toList();
          _sortExpenses();
        });
      } catch (e) {
        debugPrint('$e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_expenses.map((e) => e.toMap()).toList());
    await prefs.setString('saved_expenses', encoded);
  }

  void _sortExpenses() {
    _expenses.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  void _addExpense(String title, double amount, DateTime dueDate, DateTime? reminder) {
    setState(() {
      _expenses.add(
        Expense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          dueDate: dueDate,
          reminderDateTime: reminder,
        ),
      );
      _sortExpenses();
    });
    _saveExpenses();
  }

  void _togglePaid(int index) {
    setState(() {
      _expenses[index].isPaid = !_expenses[index].isPaid;
    });
    _saveExpenses();
  }

  void _deleteExpense(int index) {
    setState(() {
      _expenses.removeAt(index);
    });
    _saveExpenses();
  }

  double get _totalExpenses => _expenses.fold(0.0, (sum, item) => sum + item.amount);
  double get _totalPaid => _expenses.where((e) => e.isPaid).fold(0.0, (sum, item) => sum + item.amount);
  double get _totalPending => _totalExpenses - _totalPaid;
  double get _dailyGoal => _totalPending > 0 ? _totalPending / 30 : 0.0;

  // GERAÇÃO DO RELATÓRIO PDF DO MÊS
  Future<void> _generatePdfReport() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Relatorio Mensal de Despesas', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('MM/yyyy').format(DateTime.now())),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text('Resumo Geral:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Total de Contas: R\$ ${_totalExpenses.toStringAsFixed(2)}'),
                pw.Text('Total Pago: R\$ ${_totalPaid.toStringAsFixed(2)}'),
                pw.Text('Total Pendente: R\$ ${_totalPending.toStringAsFixed(2)}'),
                pw.Text('Meta Diaria Necessaria: R\$ ${_dailyGoal.toStringAsFixed(2)} / dia'),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Descricao', 'Vencimento', 'Lembrete', 'Status', 'Valor (R\$)'],
                  data: _expenses.map((e) {
                    final lembrete = e.reminderDateTime != null
                        ? DateFormat('dd/MM HH:mm').format(e.reminderDateTime!)
                        : '-';
                    return [
                      e.title,
                      DateFormat('dd/MM/yyyy').format(e.dueDate),
                      lembrete,
                      e.isPaid ? 'Pago' : 'Pendente',
                      'R\$ ${e.amount.toStringAsFixed(2)}',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  void _showAddExpenseModal() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 5));
    DateTime? reminderDate;
    TimeOfDay? reminderTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nova Despesa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Descrição da Conta', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: r'Valor (R$)', prefixText: r'R$ ', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Color(0xFF00897B)),
                title: const Text('Data de Vencimento'),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(dueDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setModalState(() => dueDate = picked);
                  },
                  child: const Text('Alterar'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active, color: Colors.orange),
                title: const Text('Lembrete / Alerta'),
                subtitle: Text(
                  reminderDate != null && reminderTime != null
                      ? '${DateFormat('dd/MM/yyyy').format(reminderDate!)} às ${reminderTime!.format(context)}'
                      : 'Nenhum lembrete definido',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setModalState(() {
                          reminderDate = pickedDate;
                          reminderTime = pickedTime;
                        });
                      }
                    }
                  },
                  child: const Text('Configurar'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final text = titleController.text.trim();
                  final value = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;

                  DateTime? finalReminder;
                  if (reminderDate != null && reminderTime != null) {
                    finalReminder = DateTime(
                      reminderDate!.year,
                      reminderDate!.month,
                      reminderDate!.day,
                      reminderTime!.hour,
                      reminderTime!.minute,
                    );
                  }

                  if (text.isNotEmpty && value > 0) {
                    _addExpense(text, value, dueDate, finalReminder);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Salvar Despesa'),
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
        actions: [
          IconButton(
            tooltip: 'Gerar Relatório PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _expenses.isEmpty ? null : _generatePdfReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: [
                          const Text('Total Geral de Contas', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            'R\$ ${_totalExpenses.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                          const Divider(height: 20),
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
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings, color: Color(0xFF00897B), size: 26),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Meta Diária Necessária (30 dias)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                                    Text('R\$ ${_dailyGoal.toStringAsFixed(2)} / dia', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(child: Text('Nenhuma conta cadastrada.'))
                      : ListView.builder(
                          itemCount: _expenses.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final item = _expenses[index];
                            final isOverdue = !item.isPaid &&
                                item.dueDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: item.isPaid
                                      ? Colors.green.shade300
                                      : (isOverdue ? Colors.red.shade300 : Colors.transparent),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: IconButton(
                                  icon: Icon(
                                    item.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: item.isPaid ? Colors.green : Colors.grey,
                                    size: 28,
                                  ),
                                  onPressed: () => _togglePaid(index),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vence: ${DateFormat('dd/MM/yyyy').format(item.dueDate)}',
                                      style: TextStyle(color: isOverdue ? Colors.red : Colors.grey.shade700, fontSize: 12),
                                    ),
                                    if (item.reminderDateTime != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.alarm, size: 12, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Alerta: ${DateFormat('dd/MM HH:mm').format(item.reminderDateTime!)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'R\$ ${item.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              'R\$ ${amount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ],
    );
  }
}
