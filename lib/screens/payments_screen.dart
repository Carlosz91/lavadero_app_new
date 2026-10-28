import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../utils/formatters.dart';
import 'payment_service.dart';

/// Página embebible de pagos. Sin Scaffold ni AppBar: vive en la barra
/// inferior del shell y pinta su propio header con gradiente de marca.
class PaymentsView extends StatefulWidget {
  final String userEmail;

  const PaymentsView({super.key, required this.userEmail});

  @override
  State<PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<PaymentsView>
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
    final httpService = HttpService();
    _userId = await httpService.getUserId();
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
        _errorMessage = friendlyErrorMessage(e);
      });
    }
  }

  Map<String, dynamic> _formatPayment(Map<String, dynamic> p) {
    final amountDouble = (p['amount'] as num?)?.toDouble() ?? 0.0;
    return {
      'id': p['_id'] ?? '',
      'plate': p['plate'] ?? 'N/A',
      'amount': formatGs(amountDouble),
      'amountDouble': amountDouble,
      'method': p['method'] as String? ?? 'Otro',
      'status': p['status'] ?? 'Pendiente',
      'date': p['date'] ?? '',
      'carId': p['carId'] ?? '',
    };
  }

  /// Key de idempotencia única por intento. El backend la exige en
  /// create-checkout-session y cachea la respuesta bajo la key: usar una key
  /// estable por pago haría que un error viejo (ej. Stripe caído) se reproduzca
  /// en cada reintento, así que cada tap genera la suya.
  String _generateIdempotencyKey() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$timestamp-${random.nextInt(999999)}-${random.nextInt(999999)}';
  }

  Future<void> _payWithStripe(Map<String, dynamic> payment) async {
    setState(() => _processingPayment = true);
    try {
      final httpService = HttpService();
      await httpService.loadToken();
      // El monto nunca viaja por el cliente: el backend toma el pago guardado.
      final response = await httpService.post(
        ApiConfig.stripeCheckoutUrl,
        {'paymentId': payment['id']},
        idempotencyKey: _generateIdempotencyKey(),
      );
      final url = response['url'] as String?;
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (!mounted) return;
          AppSnackBar.error(context, 'No se pudo abrir Stripe');
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'No se pudo iniciar el pago. ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_processingPayment) {
      return const LoadingState(message: 'Abriendo Stripe...');
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const SkeletonList(count: 4)
              : _hasError
                  ? ErrorState(message: _errorMessage, onRetry: _fetchAll)
                  : _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSummaryRow(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  /// Header de página con gradiente de marca y stats de resumen. El shell no
  /// tiene AppBar; este absorbe el inset de la barra de estado.
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        12,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mis Pagos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pagá con Stripe en un solo toque',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => _fetchAll(silent: true),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeaderStat(
                  Icons.pending_actions, 'Pendiente', _totalPending, AppColors.warning),
              const SizedBox(width: 24),
              _buildHeaderStat(
                  Icons.check_circle, 'Pagado', _totalPaid, AppColors.success),
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
                formatGs(amount),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                child: Icon(Icons.receipt_long, size: 64, color: AppColors.textHint),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'Pagado': return AppColors.success;
      case 'Pendiente': return AppColors.warning;
      case 'Cancelado': return AppColors.error;
      case 'Reembolsado': return const Color(0xFF8B5CF6);
      default: return AppColors.textHint;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pagado': return Icons.check_circle_rounded;
      case 'Pendiente': return Icons.pending_actions_rounded;
      case 'Cancelado': return Icons.cancel_rounded;
      case 'Reembolsado': return Icons.replay_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Pagado': return 'Pagado';
      case 'Pendiente': return 'Pendiente';
      case 'Cancelado': return 'Cancelado';
      case 'Reembolsado': return 'Reembolsado';
      default: return status;
    }
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, {required bool isPending}) {
    final status = payment['status'] as String;
    final method = payment['method'] as String;
    final methodColor = _getMethodColor(method);
    final statusColor = _statusColor(status);
    final isActivePending = isPending && status == 'Pendiente';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isActivePending ? AppColors.warning : methodColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActivePending ? Icons.pending_actions : _getMethodIcon(method),
                    color: isActivePending ? AppColors.warning : methodColor,
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isActivePending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: const Text('Pagar con Stripe'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF635BFF),
                          side: const BorderSide(
                            color: Color(0xFF635BFF),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _payWithStripe(payment),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Los métodos en persona (efectivo/tarjeta/transferencia) los registra el personal del lavadero.',
                style: AppTextStyles.caption,
              ),
            ],
            if (!isActivePending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(_statusIcon(status), size: 14, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel(status),
                    style: AppTextStyles.caption.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(payment['date']),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    payment['amount'],
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
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
        return const Color(0xFF8B5CF6);
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
}

/// Wrapper standalone por compatibilidad: Scaffold + AppBar con gradiente
/// alrededor de la misma página embebible.
class PaymentsScreen extends StatelessWidget {
  final String userEmail;

  const PaymentsScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: 'Mis Pagos'),
      body: PaymentsView(userEmail: userEmail),
    );
  }
}
