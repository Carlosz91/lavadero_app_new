import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';

class WashStatusScreen extends StatefulWidget {
  final String userId;

  const WashStatusScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<WashStatusScreen> createState() => _WashStatusScreenState();
}

class _WashStatusScreenState extends State<WashStatusScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _cars = [];
  Timer? _refreshTimer;
  int _currentIndex = 0;
  final HttpService _httpService = HttpService();
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // ✅ Validar userId
    if (widget.userId.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'ID de usuario inválido';
        _isLoading = false;
      });
      return;
    }
    _fetchCarsStatus();

    // ✅ Usar ApiConfig.refreshInterval en lugar de hardcodear
    _refreshTimer = Timer.periodic(ApiConfig.refreshInterval, (timer) {
      if (mounted && !_isLoading) {
        _fetchCarsStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    // ✅ Cancelar timer para evitar memory leaks
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCarsStatus({bool silent = false}) async {
    // ✅ Evitar requests si el widget ya fue destruido
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
      });
    }

    try {
      // ✅ Usar HttpService y ApiConfig
      final url = ApiConfig.getCarsStatusUrl(widget.userId);
      final data = await _httpService.get(url);

      if (!mounted) return;

      final List<Map<String, dynamic>> cars =
          List<Map<String, dynamic>>.from(data['cars'] ?? []);

      // ✅ Ordenar vehículos por prioridad
      _sortCars(cars);

      setState(() {
        _cars = cars;
        _isLoading = false;
        _hasError = false;
        _retryCount = 0;
      });
    } on UnauthorizedException {
      // ✅ Manejo específico de autenticación expirada
      if (!mounted) return;
      _handleUnauthorized();
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Sesión expirada. Por favor, inicia sesión de nuevo';
      });
    } on HttpException catch (e) {
      if (!mounted) return;
      // ✅ Reintentos automáticos
      if (_retryCount < _maxRetries) {
        _retryCount++;
        await Future.delayed(const Duration(seconds: 2));
        return _fetchCarsStatus(silent: silent);
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error inesperado. Intenta de nuevo';
      });
    }
  }

  /// ✅ Ordenar vehículos por estado
  void _sortCars(List<Map<String, dynamic>> cars) {
    cars.sort((a, b) {
      final statusA = (a['status'] ?? '').toString().toLowerCase();
      final statusB = (b['status'] ?? '').toString().toLowerCase();

      if (statusA == 'en progreso') return -1;
      if (statusB == 'en progreso') return 1;
      if (statusA == 'pendiente') return -1;
      if (statusB == 'pendiente') return 1;
      return 0;
    });
  }

  /// ✅ Manejo cuando sesión se vence
  void _handleUnauthorized() {
    _httpService.clearAuth();
    // Aquí podrías navegar a login
    // Navigator.pushReplacementNamed(context, '/login');
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No disponible';

    try {
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Gs. 0';
    final num value = amount is String ? double.tryParse(amount) ?? 0 : amount;
    return 'Gs. ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
        return Colors.green;
      case 'en progreso':
        return Colors.blue;
      case 'pendiente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
        return Icons.check_circle;
      case 'en progreso':
        return Icons.autorenew;
      case 'pendiente':
        return Icons.access_time;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStatusChips() {
    final statuses = [
      'Todos',
      'Pendiente',
      'En Progreso',
      'Completado',
      'Cancelado',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: statuses.map((status) {
          final isSelected = _currentIndex == statuses.indexOf(status);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(
                status,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _currentIndex = statuses.indexOf(status);
                });
              },
              backgroundColor: isSelected
                  ? _getStatusColor(status).withOpacity(0.2)
                  : Colors.grey.shade200,
              selectedColor: _getStatusColor(status),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color:
                    isSelected ? _getStatusColor(status) : Colors.transparent,
                width: 1.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredCars() {
    if (_currentIndex == 0) return _cars;

    final statuses = [
      'Todos',
      'Pendiente',
      'En Progreso',
      'Completado',
      'Cancelado',
    ];
    final selectedStatus = statuses[_currentIndex].toLowerCase();

    return _cars
        .where(
          (car) =>
              (car['status'] ?? '').toString().toLowerCase() == selectedStatus,
        )
        .toList();
  }

  Widget _buildStatsCard() {
    final completed = _cars
        .where(
          (car) =>
              (car['status'] ?? '').toString().toLowerCase() == 'completado',
        )
        .length;
    final inProgress = _cars
        .where(
          (car) =>
              (car['status'] ?? '').toString().toLowerCase() == 'en progreso',
        )
        .length;
    final pending = _cars
        .where(
          (car) =>
              (car['status'] ?? '').toString().toLowerCase() == 'pendiente',
        )
        .length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blueAccent.shade700,
            Colors.blueAccent.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.access_time,
            'Pendientes',
            pending,
            Colors.orange,
          ),
          _buildStatItem(
            Icons.autorenew,
            'En Progreso',
            inProgress,
            Colors.lightBlueAccent,
          ),
          _buildStatItem(
            Icons.check_circle,
            'Completados',
            completed,
            Colors.lightGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildCarCard(Map<String, dynamic> car) {
    final status = car['status']?.toString() ?? 'Pendiente';
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Placa y estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  car['plate'] ?? 'N/D',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                    letterSpacing: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ✅ Información del vehículo
            _buildCarInfo(
              Icons.directions_car,
              '${car['brand'] ?? 'N/D'} ${car['model'] ?? 'N/D'}',
              'Vehículo',
            ),
            const SizedBox(height: 12),
            _buildCarInfo(
              Icons.local_car_wash,
              car['washType'] ?? 'N/D',
              'Tipo de lavado',
            ),
            const SizedBox(height: 12),
            _buildCarInfo(
              Icons.attach_money,
              _formatCurrency(car['amount']),
              'Monto',
              valueColor: Colors.green.shade600,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ✅ Fechas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDateInfo(
                  'Registrado',
                  _formatDate(car['createdAt']),
                ),
                _buildDateInfo(
                  'Actualizado',
                  _formatDate(car['updatedAt']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Widget para información de auto
  Widget _buildCarInfo(
    IconData icon,
    String value,
    String label, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ Widget para información de fecha
  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          date,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.blueAccent,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando estado de lavado...',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _fetchCarsStatus,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_car_wash,
                size: 100,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay vehículos registrados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cuando registres tu vehículo,\npodrás ver su estado de lavado aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.directions_car, size: 20),
                label: const Text('Registrar vehículo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Widget para cuando no hay vehículos con el filtro seleccionado
  Widget _buildNoFilteredState() {
    return Center(
      child: Padding(
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
                Icons.filter_list,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay vehículos con este filtro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCars = _getFilteredCars();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('🚗 Estado de Lavado'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCarsStatus,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
              ? _buildErrorState()
              : _cars.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchCarsStatus,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // ✅ Stats cards mejorado
                              _buildStatsCard(),
                              const SizedBox(height: 20),

                              // ✅ Status chips mejorado
                              _buildStatusChips(),
                              const SizedBox(height: 20),

                              // ✅ Lista de autos
                              if (filteredCars.isEmpty)
                                _buildNoFilteredState()
                              else
                                Column(
                                  children: filteredCars
                                      .map((car) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _buildCarCard(car),
                                          ))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }
}
