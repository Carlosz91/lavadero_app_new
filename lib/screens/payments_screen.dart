import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import 'payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  final String userEmail;

  const PaymentsScreen({super.key, required this.userEmail});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _pendingPayments = [];
  List<Map<String, dynamic>> _historyPayments = [];
  double _totalPending = 0.0;
  double _totalPaid = 0.0;
  bool _processingPayment = false;
  String? _userId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserIdAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      _fetchAll();
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Usuario no autenticado';
      });
    }
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final results = await Future.wait([
        PaymentService.getPayments(status: 'Pendiente'),
        PaymentService.getPayments(),
      ]);

      final pending = results[0];
      final allPayments = results[1];

      setState(() {
        _pendingPayments = pending.map((p) => _formatPayment(p)).toList();
        _historyPayments = allPayments
            .where((p) => p['status'] != 'Pendiente')
            .map((p) => _formatPayment(p))
            .toList();

        _totalPending =
            _pendingPayments.fold(0.0, (sum, p) => sum + (p['amountDouble'] as double));
        _totalPaid =
            _historyPayments.fold(0.0, (sum, p) => sum + (p['amountDouble'] as double));

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error al cargar pagos: $e';
      });
    }
  }

  Map<String, dynamic> _formatPayment(Map<String, dynamic> p) {
    final amountDouble = (p['amount'] as num?)?.toDouble() ?? 0.0;
    return {
      'id': p['_id'] ?? '',
      'plate': p['plate'] ?? 'N/A',
      'amount': 'Gs. ${_formatAmount(amountDouble)}',
      'amountDouble': amountDouble,
      'method': p['method'] as String? ?? 'Otro',
      'status': p['status'] ?? 'Pendiente',
      'date': p['date'] ?? '',
      'carId': p['carId'] ?? '',
    };
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
    }
    return amount.toStringAsFixed(0);
  }

  Future<void> _payWithStripe(Map<String, dynamic> payment) async {
    setState(() => _processingPayment = true);
    try {
      final httpService = HttpService();
      await httpService.loadToken();
      final response = await httpService.post(
        '${ApiConfig.baseUrl}/api/stripe/create-checkout-session',
        {
          'paymentId': payment['id'],
          'plate': payment['plate'],
          'amount': payment['amountDouble'],
        },
      );
      final url = response['url'] as String?;
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('No se pudo abrir Stripe', success: false);
        }
      }
    } catch (e) {
      _showSnackBar('Error al conectar con Stripe: $e', success: false);
    } finally {
      setState(() => _processingPayment = false);
    }
  }

  Future<void> _processPayment(Map<String, dynamic> payment, String method) async {
    setState(() => _processingPayment = true);
    try {
      await PaymentService.updatePaymentStatus(payment['id'], 'Pagado', method: method);
      _showSnackBar('Pago con $method registrado exitosamente', success: true);
      await _fetchAll(silent: true);
    } catch (e) {
      _showSnackBar('Error en el pago: $e', success: false);
    } finally {
      setState(() => _processingPayment = false);
    }
  }

  void _showSnackBar(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _processingPayment || _isLoading
          ? const LoadingState(message: 'Procesando...')
          : _hasError
              ? ErrorState(message: _errorMessage, onRetry: _fetchAll)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildSummaryRow(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Mis Pagos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => _fetchAll(silent: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildHeaderStat(Icons.pending_actions, 'Pendiente', _totalPending, AppColors.warning),
              const SizedBox(width: 24),
              _buildHeaderStat(Icons.check_circle, 'Pagado', _totalPaid, AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String label, double amount, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                'Gs. ${_formatAmount(amount)}',
                style: TextStyle(
                  color: amount > 0 ? color : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _buildSummaryChip(
            Icons.pending_actions,
            '${_pendingPayments.length} pendiente${_pendingPayments.length == 1 ? '' : 's'}',
            _pendingPayments.isEmpty ? AppColors.textHint : AppColors.warning,
          ),
          const SizedBox(width: 12),
          _buildSummaryChip(
            Icons.history,
            '${_historyPayments.length} pagado${_historyPayments.length == 1 ? '' : 's'}',
            _historyPayments.isEmpty ? AppColors.textHint : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 18),
                const SizedBox(width: 6),
                Text('Pendientes (${_pendingPayments.length})'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, size: 18),
                const SizedBox(width: 6),
                Text('Historial (${_historyPayments.length})'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPendingTab(),
        _buildHistoryTab(),
      ],
    );
  }

  Widget _buildPendingTab() {
    if (_pendingPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
              ),
              const SizedBox(height: 24),
              Text('Sin deudas pendientes', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                'No tenés pagos pendientes. Cuando tengas un lavado completado, aparecerá aquí.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchAll(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _pendingPayments.length,
        itemBuilder: (context, index) {
          final payment = _pendingPayments[index];
          return _buildPaymentCard(payment, isPending: true);
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_historyPayments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, size: 64, color: AppColors.textHint),
              ),
              const SizedBox(height: 24),
              Text('Sin historial', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              Text(
                'Cuando realices pagos, aparecerán aquí.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchAll(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: _historyPayments.length,
        itemBuilder: (context, index) {
          final payment = _historyPayments[index];
          return _buildPaymentCard(payment, isPending: false);
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, {required bool isPending}) {
    final status = payment['status'] as String;
    final method = payment['method'] as String;
    final methodColor = _getMethodColor(method);
    final isPaid = status == 'Pagado';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPending ? AppColors.warning.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: isPending
              ? Border.all(color: AppColors.warning.withValues(alpha: 0.3))
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isPending ? AppColors.warning : methodColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPending ? Icons.pending_actions : _getMethodIcon(method),
                    color: isPending ? AppColors.warning : methodColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment['plate'],
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPaid ? 'Pagado' : 'Pendiente',
                    style: TextStyle(
                      color: isPaid ? AppColors.success : AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Pagar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showPaymentOptions(payment),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: const Text('Stripe'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF635BFF),
                          side: const BorderSide(color: Color(0xFF635BFF), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _payWithStripe(payment),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!isPending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(payment['date']),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                  const Spacer(),
                  Text(
                    payment['amount'],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPaid ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null || date == '') return '';
    try {
      if (date is String) {
        return date.split('T').first;
      }
      if (date is DateTime) {
        return DateFormat('dd/MM/yyyy').format(date);
      }
      return date.toString().split('T').first;
    } catch (_) {
      return '';
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'Efectivo':
        return Icons.attach_money;
      case 'Tarjeta':
      case 'Tarjeta de Crédito':
      case 'Tarjeta de Crédito/Débito':
        return Icons.credit_card;
      case 'Transferencia':
      case 'Transferencia Bancaria':
        return Icons.account_balance;
      case 'Mercado Pago':
        return Icons.payment;
      case 'Stripe':
        return Icons.credit_card;
      default:
        return Icons.receipt;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'Efectivo':
        return AppColors.success;
      case 'Tarjeta':
      case 'Tarjeta de Crédito':
      case 'Tarjeta de Crédito/Débito':
        return AppColors.primary;
      case 'Transferencia':
      case 'Transferencia Bancaria':
        return Colors.purple;
      case 'Mercado Pago':
        return const Color(0xFF00B1EA);
      case 'Stripe':
        return const Color(0xFF635BFF);
      case 'Otro':
        return AppColors.textHint;
      default:
        return AppColors.textHint;
    }
  }

  void _showPaymentOptions(Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payment, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seleccionar método', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                      Text(payment['amount'], style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _paymentOptionButton(
                title: 'Efectivo',
                icon: Icons.attach_money,
                color: AppColors.success,
                onTap: () { Navigator.pop(context); _processPayment(payment, 'Efectivo'); },
              ),
              const SizedBox(height: 10),
              _paymentOptionButton(
                title: 'Tarjeta de Crédito/Débito',
                icon: Icons.credit_card,
                color: AppColors.primary,
                onTap: () { Navigator.pop(context); _processPayment(payment, 'Tarjeta'); },
              ),
              const SizedBox(height: 10),
              _paymentOptionButton(
                title: 'Transferencia Bancaria',
                icon: Icons.account_balance,
                color: Colors.purple,
                onTap: () { Navigator.pop(context); _processPayment(payment, 'Transferencia'); },
              ),
              const SizedBox(height: 10),
              _paymentOptionButton(
                title: 'Mercado Pago',
                icon: Icons.payment,
                color: const Color(0xFF00B1EA),
                onTap: () { Navigator.pop(context); _processPayment(payment, 'Mercado Pago'); },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentOptionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
