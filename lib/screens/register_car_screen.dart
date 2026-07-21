import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/water_animation.dart';

class RegisterCarScreen extends StatefulWidget {
  const RegisterCarScreen({super.key});

  @override
  State<RegisterCarScreen> createState() => _RegisterCarScreenState();
}

class _RegisterCarScreenState extends State<RegisterCarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _brandController = TextEditingController();
  final _amountController = TextEditingController();

  final List<String> _washTypes = [
    'B\u00e1sico',
    'Premium',
    'Completo',
    'Detailing'
  ];
  final Map<String, double> _washPrices = {
    'B\u00e1sico': 50000,
    'Premium': 80000,
    'Completo': 120000,
    'Detailing': 200000,
  };

  String _selectedWashType = 'B\u00e1sico';
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
  int _availableSlots = 5;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text = _washPrices[_selectedWashType]!.toStringAsFixed(0);
    _checkAvailability(_scheduledDate);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _brandController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _updateAmount(String type) {
    setState(() {
      _selectedWashType = type;
      _amountController.text = _washPrices[type]!.toStringAsFixed(0);
    });
  }

  Future<void> _checkAvailability(DateTime date) async {
    try {
      final httpService = HttpService();
      await httpService.loadToken();
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await httpService.get(
        '${ApiConfig.baseUrl}${ApiConfig.carsAvailability}?date=$dateStr',
      );
      if (mounted) {
        setState(() => _availableSlots = data['available'] as int? ?? 5);
      }
    } catch (_) {
      if (mounted) setState(() => _availableSlots = 5);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
      _checkAvailability(picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  Future<void> _registerCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_availableSlots <= 0) {
      _setError('No hay cupos disponibles para esta fecha');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        throw Exception('No se encontr\u00f3 el usuario. Inicia sesi\u00f3n nuevamente.');
      }

      final httpService = HttpService();
      await httpService.loadToken();

      final pendingData = await httpService.get(
        '${ApiConfig.baseUrl}/api/payments?status=Pendiente',
      );
      final pendingList = (pendingData['data'] as List?) ?? [];
      if (pendingList.isNotEmpty) {
        throw Exception('Tenés un pago pendiente. Pagalo antes de registrar otro vehículo.');
      }

      final plate = _plateController.text.trim().toUpperCase();
      final model = _modelController.text.trim();
      final brand = _brandController.text.trim();
      final washType = _selectedWashType;
      final amount = double.parse(_amountController.text.trim());

      if (amount <= 0) throw Exception('El monto debe ser mayor a cero');

      final scheduledDateStr =
          '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}';
      final scheduledTimeStr =
          '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}';

      final response = await httpService.post(
        '${ApiConfig.baseUrl}${ApiConfig.carsRegister}',
        {
          'plate': plate,
          'model': model,
          'brand': brand,
          'washType': washType,
          'amount': amount,
          'scheduledDate': scheduledDateStr,
          'scheduledTime': scheduledTimeStr,
          'userId': userId,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Veh\u00edculo registrado'),
          backgroundColor: AppColors.success,
        ),
      );

      _formKey.currentState?.reset();
      _updateAmount('B\u00e1sico');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      _setError('Tiempo de espera agotado. Verifica tu conexi\u00f3n.');
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Registrar Vehículo'),
      body: WaterBackground(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  StaggeredFadeIn(index: 0, child: _buildHeader()),
                  const SizedBox(height: 24),
                  StaggeredFadeIn(index: 1, child: _buildSectionTitle('Información del Vehículo')),
                  const SizedBox(height: 16),
                  StaggeredFadeIn(index: 2, child: _buildInputField(
                    controller: _plateController,
                    label: 'Placa',
                    icon: Icons.confirmation_number,
                    hint: 'ABC123',
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingrese la placa';
                      if (value.length < 4) return 'Mínimo 4 caracteres';
                      return null;
                    },
                  )),
                  const SizedBox(height: 16),
                  StaggeredFadeIn(index: 3, child: _buildInputField(
                    controller: _modelController,
                    label: 'Modelo',
                    icon: Icons.model_training,
                    hint: 'Civic, Corolla...',
                    validator: (value) => value == null || value.isEmpty ? 'Ingrese el modelo' : null,
                  )),
                  const SizedBox(height: 16),
                  StaggeredFadeIn(index: 4, child: _buildInputField(
                    controller: _brandController,
                    label: 'Marca',
                    icon: Icons.branding_watermark,
                    hint: 'Toyota, Honda...',
                    validator: (value) => value == null || value.isEmpty ? 'Ingrese la marca' : null,
                  )),
                  const SizedBox(height: 24),
                  StaggeredFadeIn(index: 5, child: _buildSectionTitle('Seleccione el Tipo de Lavado')),
                  const SizedBox(height: 12),
                  ..._washTypes.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StaggeredFadeIn(
                        index: 6 + e.key,
                        child: _buildWashOption(e.value, _washPrices[e.value]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  StaggeredFadeIn(index: 10, child: _buildSectionTitle('Agendar Lavado')),
                  const SizedBox(height: 12),
                  StaggeredFadeIn(index: 11, child: _buildDateTimePicker()),
                  const SizedBox(height: 20),
                  StaggeredFadeIn(index: 12, child: _buildInputField(
                    controller: _amountController,
                    label: 'Monto (Gs.)',
                    icon: Icons.attach_money,
                    readOnly: true,
                  )),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    StaggeredFadeIn(index: 13, child: ErrorBox(message: _errorMessage!)),
                  ],
                  const SizedBox(height: 24),
                  StaggeredFadeIn(index: 14, child: _buildActionButtons()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Registro de Veh\u00edculo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete los datos del veh\u00edculo',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: AppTextStyles.h3),
    );
  }

  Widget _buildDateTimePicker() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final dateTime = DateTime(
      _scheduledDate.year, _scheduledDate.month, _scheduledDate.day,
      _scheduledTime.hour, _scheduledTime.minute,
    );

    final slotsFull = _availableSlots <= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: slotsFull ? AppColors.error : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_today, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fecha', style: AppTextStyles.caption),
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(_scheduledDate),
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.access_time, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _selectTime,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hora', style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        timeFormat.format(dateTime),
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _buildWashOption(String type, double price) {
    final isSelected = _selectedWashType == type;
    return GestureDetector(
      onTap: () => _updateAmount(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIcon(type),
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 24,
            ),
          ),
          title: Text(
            type,
            style: AppTextStyles.body.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            'Gs. ${price.toStringAsFixed(0)}',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          trailing: isSelected
              ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                )
              : null,
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'Premium':
        return Icons.local_car_wash;
      case 'Completo':
        return Icons.clean_hands;
      case 'Detailing':
        return Icons.details;
      default:
        return Icons.local_car_wash;
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        GradientButton(
          label: _isLoading ? 'Registrando...' : 'Registrar Veh\u00edculo',
          icon: Icons.save,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _registerCar,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            label: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }
}
