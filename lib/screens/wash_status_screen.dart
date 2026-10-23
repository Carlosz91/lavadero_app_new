import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';
import 'register_car_screen.dart';

/// Página embebible con el estado de lavado. Sin Scaffold ni AppBar: la usa la
/// barra inferior del shell, que le provee destino y la posiciones del sistema.
class WashStatusView extends StatefulWidget {
  final String userId;

  const WashStatusView({super.key, required this.userId});

  @override
  State<WashStatusView> createState() => _WashStatusViewState();
}

class _WashStatusViewState extends State<WashStatusView> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _cars = [];
  Timer? _refreshTimer;
  int _currentIndex = 0;
  final HttpService _httpService = HttpService();
  int _retryCount = 0;
  static const int _maxRetries = 3;

  final List<String> _statuses = [
    'Todos',
    'Pendiente',
    'En Progreso',
    'Completado',
    'Cancelado',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.userId.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'ID de usuario inválido';
        _isLoading = false;
      });
      return;
    }
    _fetchCarsStatus();
    _refreshTimer = Timer.periodic(ApiConfig.refreshInterval, (timer) {
      if (mounted && !_isLoading) {
        _fetchCarsStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCarsStatus({bool silent = false}) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
      });
    }

    try {
      await _httpService.loadToken();
      final url = ApiConfig.getCarsStatusUrl(widget.userId);
      final data = await _httpService.get(url);

      if (!mounted) return;

      final List<Map<String, dynamic>> cars =
          List<Map<String, dynamic>>.from(data['data'] ?? data['cars'] ?? []);

      _sortCars(cars);

      setState(() {
        _cars = cars;
        _isLoading = false;
        _hasError = false;
        _retryCount = 0;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      await _httpService.clearAuth();
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Sesión expirada. Por favor, inicia sesión de nuevo';
      });
    } on HttpException catch (e) {
      if (!mounted) return;
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
    if (amount == null) return formatGs(0);
    final num value = amount is String ? double.tryParse(amount) ?? 0 : amount;
    return formatGs(value);
  }

  List<Map<String, dynamic>> _getFilteredCars() {
    if (_currentIndex == 0) return _cars;
    final selectedStatus = _statuses[_currentIndex].toLowerCase();
    return _cars
        .where(
          (car) =>
              (car['status'] ?? '').toString().toLowerCase() == selectedStatus,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCars = _getFilteredCars();

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const SkeletonList(count: 4)
              : _hasError
                  ? ErrorState(message: _errorMessage, onRetry: _fetchCarsStatus)
                  : _cars.isEmpty
                      ? _buildEmptyState()
                      : WaterBackground(
                          child: RefreshIndicator(
                            onRefresh: _fetchCarsStatus,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Column(
                                children: [
                                  StaggeredFadeIn(index: 0, child: _buildStatsCard()),
                                  const SizedBox(height: 20),
                                  StaggeredFadeIn(index: 1, child: _buildStatusChips()),
                                  const SizedBox(height: 20),
                                  if (filteredCars.isEmpty)
                                    _buildNoFilteredState()
                                  else
                                    Column(
                                      children: filteredCars
                                          .asMap()
                                          .entries
                                          .map((e) => Padding(
                                                padding: const EdgeInsets.only(bottom: 12),
                                                child: StaggeredFadeIn(
                                                  index: 2 + e.key,
                                                  child: _buildCarCard(e.value),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  /// Header de página pintado sobre el gradiente de marca. El shell no tiene
  /// AppBar, así que este absorbe el inset de la barra de estado.
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estado del lavado',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Seguí tu vehículo en tiempo real',
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
            onPressed: () => _fetchCarsStatus(),
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final completed = _cars
        .where((car) =>
            (car['status'] ?? '').toString().toLowerCase() == 'completado')
        .length;
    final inProgress = _cars
        .where((car) =>
            (car['status'] ?? '').toString().toLowerCase() == 'en progreso')
        .length;
    final pending = _cars
        .where((car) =>
            (car['status'] ?? '').toString().toLowerCase() == 'pendiente')
        .length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.access_time, 'Pendientes', pending, AppColors.warning),
          _buildStatItem(
              Icons.autorenew, 'En Progreso', inProgress, AppColors.primaryLight),
          _buildStatItem(
              Icons.check_circle, 'Completados', completed, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
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

  Widget _buildStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statuses.map((status) {
          final isSelected = _currentIndex == _statuses.indexOf(status);
          final chipColor = _getStatusColorForChip(status);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(
                status,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _currentIndex = _statuses.indexOf(status);
                });
              },
              backgroundColor: isSelected ? chipColor : AppColors.inputFill,
              selectedColor: chipColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              side: BorderSide(
                color: isSelected ? chipColor : AppColors.border,
                width: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColorForChip(String status) {
    switch (status.toLowerCase()) {
      case 'completado':
        return AppColors.success;
      case 'en progreso':
        return AppColors.primary;
      case 'pendiente':
        return AppColors.warning;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildCarCard(Map<String, dynamic> car) {
    final status = car['status']?.toString() ?? 'Pendiente';

    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => _showCarDetails(car),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                car['plate'] ?? 'N/D',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
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
            valueColor: AppColors.success,
          ),
          if (car['scheduledDate'] != null) ...[
            const SizedBox(height: 12),
            _buildCarInfo(
              Icons.calendar_today,
              '${_formatDate(car['scheduledDate'])} ${car['scheduledTime'] ?? ''}',
              'Agendado',
              valueColor: AppColors.warning,
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo('Registrado', _formatDate(car['createdAt'])),
              _buildDateInfo('Actualizado', _formatDate(car['updatedAt'])),
            ],
          ),
        ],
      ),
    );
  }

  void _showCarDetails(Map<String, dynamic> car) {
    AppSnackBar.info(context, 'Lavado en estado "${car['status'] ?? 'N/D'}"');
  }

  Widget _buildCarInfo(
    IconData icon,
    String value,
    String label, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.caption,
            ),
            Text(
              value,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateInfo(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(date, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.local_car_wash,
      title: 'No hay vehículos registrados',
      subtitle: 'Cuando registres tu vehículo,\npodrás ver su estado de lavado aquí.',
      actionLabel: 'Registrar vehículo',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RegisterCarScreen()),
      ),
    );
  }

  Widget _buildNoFilteredState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.filter_list,
              size: 48,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay vehículos con este filtro',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Wrapper standalone por compatibilidad: Scaffold + AppBar con gradiente
/// alrededor de la misma página embebible.
class WashStatusScreen extends StatelessWidget {
  final String userId;

  const WashStatusScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: 'Estado de Lavado'),
      body: WashStatusView(userId: userId),
    );
  }
}
