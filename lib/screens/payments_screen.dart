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
  List<Map<String, dynamic>> _payments = [];
  String? _plate;
  double _amount = 0.0;
  double _totalPaid = 0.0;
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
      _fetchPayments();
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Usuario no autenticado';
      });
    }
  }

  Future<void> _fetchPayments({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      if (_userId == null) throw Exception('No se encontr\u00f3 userId');

      final payments = await PaymentService.getWashesByStatus(
        userId: _userId!,
        status: 'Completado',
      );

      setState(() {
        _plate = payments.isNotEmpty ? payments.first['plate'] : 'N/A';

        _payments = payments.map<Map<String, dynamic>>((p) {
          final amountDouble = (p['amount'] as num?)?.toDouble() ?? 0.0;
          final method = p['method'] as String? ?? 'Desconocido';
          return {
            'id': p['_id'] ?? '',
            'amount': 'Gs. ${amountDouble.toStringAsFixed(0)}',
            'amountDouble': amountDouble,
            'method': method,
            'status': p['status'] ?? 'Pendiente',
            'date': p['date'] ?? '',
            'icon': _getMethodIcon(method),
            'color': _getMethodColor(method),
          };
        }).toList();

        _totalPaid =
            _payments.fold(0.0, (sum, p) => sum + (p['amountDouble'] as double));
        _amount =
            _payments.isNotEmpty ? _payments.first['amountDouble'] : 0.0;

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

  Future<void> _payWithStripe() async {
    setState(() => _processingPayment = true);

    try {
      final httpService = HttpService();
      await httpService.loadToken();

      final response = await httpService.post(
        '${ApiConfig.baseUrl}/api/stripe/create-checkout-session',
        {
          'plate': _plate != 'N/A' ? _plate : 'N/D',
          'amount': _amount,
          'description': 'Lavado de veh\u00edculo ${_plate ?? 'N/D'}',
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

  Future<void> _processPayment(String method) async {
    setState(() => _processingPayment = true);

    try {
      await PaymentService.createPayment(
        plate: _plate != 'N/A' ? _plate! : 'N/D',
        method: method,
        amount: _amount,
      );

      _showSnackBar('Pago con $method registrado exitosamente', success: true);
      await _fetchPayments(silent: true);
    } catch (e) {
      _showSnackBar('Error en el pago: $e', success: false);
    } finally {
      setState(() => _processingPayment = false);
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'Tarjeta de Cr\u00e9dito':
        return Icons.credit_card;
      case 'Efectivo':
        return Icons.attach_money;
      case 'Transferencia':
        return Icons.account_balance;
      case 'Mercado Pago':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'Tarjeta de Cr\u00e9dito':
        return AppColors.primary;
      case 'Efectivo':
        return AppColors.success;
      case 'Transferencia':
        return Colors.purple;
      case 'Mercado Pago':
        return AppColors.warning;
      default:
        return AppColors.textHint;
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
              ? ErrorState(message: _errorMessage, onRetry: _fetchPayments)
              : _buildContent(),
      floatingActionButton: !_processingPayment && !_isLoading && !_hasError
          ? FloatingActionButton.extended(
              onPressed: _showPaymentOptions,
              icon: const Icon(Icons.payment),
              label: const Text('Pagar'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                _buildPaymentHistory(),
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
                  'Gestiona tus pagos',
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
        child: Column(
          children: [
            _buildStatItem(
              icon: Icons.directions_car,
              label: 'Veh\u00edculo',
              value: _plate ?? 'N/A',
            ),
            const Divider(height: 32),
            _buildStatItem(
              icon: Icons.attach_money,
              label: 'Monto a pagar',
              value:
                  _plate != 'N/A' ? 'Gs. ${_amount.toStringAsFixed(0)}' : 'N/A',
              valueColor: AppColors.error,
            ),
            const Divider(height: 32),
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Total pagado',
              value: 'Gs. ${_totalPaid.toStringAsFixed(0)}',
              valueColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistory() {
    if (_payments.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No hay historial de pagos',
        subtitle: 'Realiza tu primer pago para ver el historial',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Pagos',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              final statusColor = payment['status'] == 'Completado'
                  ? AppColors.success
                  : AppColors.warning;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (payment['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      payment['icon'],
                      color: payment['color'],
                      size: 24,
                    ),
                  ),
                  title: Text(
                    payment['amount'],
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${payment['method']} \u2022 ${payment['date']}',
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      payment['status'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentOptions() {
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
                'Seleccionar m\u00e9todo de pago',
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              _paymentOptionButton(
                title: 'Tarjeta de Cr\u00e9dito/D\u00e9bito',
                icon: Icons.credit_card,
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment('Tarjeta de Cr\u00e9dito');
                },
              ),
              const SizedBox(height: 12),
              _paymentOptionButton(
                title: 'Transferencia Bancaria',
                icon: Icons.account_balance,
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment('Transferencia');
                },
              ),
              const SizedBox(height: 12),
              _paymentOptionButton(
                title: 'Stripe (Tarjeta)',
                icon: Icons.credit_card,
                color: const Color(0xFF635BFF),
                onTap: () {
                  Navigator.pop(context);
                  _payWithStripe();
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
