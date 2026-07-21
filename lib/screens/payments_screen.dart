import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import 'payment_service.dart';

class PaymentsScreen extends StatefulWidget {
  final String userEmail;

  const PaymentsScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _pendingPayments = [];
  double _totalPending = 0.0;
  bool _processingPayment = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetch();
  }

  Future<void> _loadUserIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      _fetchPendingPayments();
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Usuario no autenticado';
      });
    }
  }

  Future<void> _fetchPendingPayments({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final payments = await PaymentService.getPayments(status: 'Pendiente');

      setState(() {
        _pendingPayments = payments.map<Map<String, dynamic>>((p) {
          final amountDouble = (p['amount'] as num?)?.toDouble() ?? 0.0;
          final method = p['method'] as String? ?? 'Otro';
          return {
            'id': p['_id'] ?? '',
            'plate': p['plate'] ?? 'N/A',
            'amount': 'Gs. ${amountDouble.toStringAsFixed(0)}',
            'amountDouble': amountDouble,
            'method': method,
            'status': p['status'] ?? 'Pendiente',
            'date': p['date'] ?? '',
            'carId': p['carId'] ?? '',
          };
        }).toList();

        _totalPending =
            _pendingPayments.fold(0.0, (sum, p) => sum + (p['amountDouble'] as double));

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
      await PaymentService.updatePaymentStatus(
        payment['id'],
        'Pagado',
        method: method,
      );

      _showSnackBar('Pago con $method registrado exitosamente', success: true);
      await _fetchPendingPayments(silent: true);
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
              ? ErrorState(message: _errorMessage, onRetry: _fetchPendingPayments)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 20),
                _buildPendingList(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasarela de Pagos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Pagos pendientes',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.pending_actions, color: AppColors.warning, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total pendiente',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gs. ${_totalPending.toStringAsFixed(0)}',
                    style: AppTextStyles.h2.copyWith(color: AppColors.error),
                  ),
                ],
              ),
            ),
            Text(
              '${_pendingPayments.length} pago${_pendingPayments.length == 1 ? '' : 's'}',
              style: AppTextStyles.body.copyWith(color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingPayments.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'Sin pagos pendientes',
        subtitle: 'No tenés deudas pendientes',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagos pendientes',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingPayments.length,
            itemBuilder: (context, index) {
              final payment = _pendingPayments[index];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.directions_car, color: AppColors.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment['plate'],
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  payment['amount'],
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Pendiente',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.payment, size: 18),
                              label: const Text('Pagado'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(color: AppColors.success),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showPaymentOptions(payment),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.credit_card, size: 18),
                              label: const Text('Stripe'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF635BFF),
                                side: const BorderSide(color: Color(0xFF635BFF)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _payWithStripe(payment),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
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
              Text(
                'Seleccionar método de pago',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              _paymentOptionButton(
                title: 'Efectivo',
                icon: Icons.attach_money,
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment(payment, 'Efectivo');
                },
              ),
              const SizedBox(height: 12),
              _paymentOptionButton(
                title: 'Tarjeta de Crédito/Débito',
                icon: Icons.credit_card,
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment(payment, 'Tarjeta');
                },
              ),
              const SizedBox(height: 12),
              _paymentOptionButton(
                title: 'Transferencia Bancaria',
                icon: Icons.account_balance,
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment(payment, 'Transferencia');
                },
              ),
              const SizedBox(height: 12),
              _paymentOptionButton(
                title: 'Mercado Pago',
                icon: Icons.payment,
                color: const Color(0xFF00B1EA),
                onTap: () {
                  Navigator.pop(context);
                  _processPayment(payment, 'Mercado Pago');
                },
              ),
              const SizedBox(height: 12),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
