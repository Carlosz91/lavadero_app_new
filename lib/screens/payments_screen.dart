import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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

  // ✅ Colores del sistema de diseño
  final Color _primaryColor = Colors.blueAccent;
  final Color _successColor = Colors.green;
  final Color _warningColor = Colors.orangeAccent;
  final Color _errorColor = Colors.redAccent;

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
        _errorMessage = "Usuario no autenticado";
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
      if (_userId == null) throw Exception("No se encontró userId");

      // ✅ Traer lavados/pagos completados (sin token)
      final payments = await PaymentService.getWashesByStatus(
        userId: _userId!,
        status: 'Completado',
      );

      setState(() {
        _plate = payments.isNotEmpty ? payments.first["plate"] : 'N/A';

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

        _totalPaid = _payments.fold(
            0.0, (sum, p) => sum + (p['amountDouble'] as double));

        _amount = _payments.isNotEmpty ? _payments.first['amountDouble'] : 0.0;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Error al cargar pagos: $e";
      });
    }
  }

  Future<void> _processPayment(String method) async {
    setState(() => _processingPayment = true);

    try {
      // ✅ Crear pago sin token (manejado automáticamente)
      await PaymentService.createPayment(
        plate: _plate != 'N/A' ? _plate! : 'N/D',
        method: method,
        amount: _amount,
      );

      _showSnackBar('Pago con $method registrado ✅', success: true);

      // Refrescar pagos
      await _fetchPayments(silent: true);
    } catch (e) {
      _showSnackBar('❌ Error en el pago: $e', success: false);
    } finally {
      setState(() => _processingPayment = false);
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'Tarjeta de Crédito':
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
      case 'Tarjeta de Crédito':
        return Colors.blueAccent;
      case 'Efectivo':
        return Colors.green;
      case 'Transferencia':
        return Colors.purple;
      case 'Mercado Pago':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }

  void _showSnackBar(String message, {required bool success}) {
    final color = success ? _successColor : _errorColor;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _processingPayment || _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : _buildContent(),
      floatingActionButton: !_processingPayment && !_isLoading && !_hasError
          ? FloatingActionButton.extended(
              onPressed: _showPaymentOptions,
              backgroundColor: _primaryColor,
              elevation: 4,
              icon: const Icon(Icons.payment),
              label: const Text('Pagar'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ✅ Widget para loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _processingPayment ? 'Procesando pago...' : 'Cargando pagos...',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: _errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _fetchPayments(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
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
                const SizedBox(height: 20),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryColor,
            _primaryColor.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
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
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatItem(
              icon: Icons.directions_car,
              label: 'Vehículo',
              value: _plate ?? 'N/A',
            ),
            const Divider(height: 32),
            _buildStatItem(
              icon: Icons.attach_money,
              label: 'Monto a pagar',
              value:
                  _plate != 'N/A' ? 'Gs. ${_amount.toStringAsFixed(0)}' : 'N/A',
              valueColor: _errorColor,
            ),
            const Divider(height: 32),
            _buildStatItem(
              icon: Icons.check_circle,
              label: 'Total pagado',
              value: 'Gs. ${_totalPaid.toStringAsFixed(0)}',
              valueColor: _successColor,
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
    Color valueColor = Colors.black,
  }) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentHistory() {
    if (_payments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay historial de pagos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Realiza tu primer pago para ver el historial',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Pagos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payments.length,
            itemBuilder: (context, index) {
              final payment = _payments[index];
              final statusColor = payment['status'] == 'Completado'
                  ? _successColor
                  : _warningColor;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (payment['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      payment['icon'],
                      color: payment['color'],
                    ),
                  ),
                  title: Text(
                    payment['amount'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${payment['method']} • ${payment['date']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
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
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            runSpacing: 12,
            children: [
              Text(
                'Seleccionar método de pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              _paymentOptionButton(
                title: 'Tarjeta de Crédito/Débito',
                icon: Icons.credit_card,
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment('Tarjeta de Crédito');
                },
              ),
              _paymentOptionButton(
                title: 'Transferencia Bancaria',
                icon: Icons.account_balance,
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _processPayment('Transferencia');
                },
              ),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 3,
        shadowColor: Colors.black26,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color, width: 2),
        ),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color.fromARGB(
                (0.1 * 255).round(), color.red, color.green, color.blue),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          Icon(Icons.arrow_forward, color: color),
        ],
      ),
    );
  }
}
