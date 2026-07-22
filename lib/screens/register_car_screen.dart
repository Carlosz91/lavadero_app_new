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

  int _currentStep = 0;
  String _selectedColor = 'Blanco';
  String _selectedWashType = 'Básico';
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);
  int _availableSlots = 5;
  bool _isLoading = false;
  String? _errorMessage;

  final List<Color> _colorOptions = [
    const Color(0xFF1A237E),
    const Color(0xFFB71C1C),
    Colors.white,
    Colors.black,
    const Color(0xFF9E9E9E),
    const Color(0xFF2E7D32),
  ];
  final List<String> _colorNames = ['Azul', 'Rojo', 'Blanco', 'Negro', 'Plateado', 'Verde'];

  final List<WashService> _washServices = [
    WashService('Básico', 50000, Icons.wash_outlined, 'Limpieza exterior básica y secado', null),
    WashService('Premium', 80000, Icons.local_car_wash, 'Lavado a presión con cera protectora', 'Popular'),
    WashService('Premium Plus', 100000, Icons.sanitizer, 'Lavado interior y cera protectora básica', null),
    WashService('Completo', 120000, Icons.cleaning_services, 'Lavado interior y exterior con champú premium', null),
    WashService('Detailing', 200000, Icons.auto_awesome, 'Lavado interior profundo con cera protectora', null),
    WashService('Full Package', 300000, Icons.workspace_premium, 'Detailing completo + recubrimiento cerámico', 'Premium'),
  ];

  @override
  void initState() {
    super.initState();
    _checkAvailability(_scheduledDate);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  double get _selectedPrice => _washServices.firstWhere((s) => s.name == _selectedWashType).price;

  Future<void> _checkAvailability(DateTime date) async {
    try {
      final httpService = HttpService();
      await httpService.loadToken();
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await httpService.get('${ApiConfig.baseUrl}${ApiConfig.carsAvailability}?date=$dateStr');
      if (mounted) setState(() => _availableSlots = data['available'] as int? ?? 5);
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
    final picked = await showTimePicker(context: context, initialTime: _scheduledTime);
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    setState(() => _currentStep++);
  }

  Future<void> _registerCar() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    if (_availableSlots <= 0) { _setError('No hay cupos disponibles para esta fecha'); return; }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null || userId.isEmpty) throw Exception('No se encontró el usuario. Inicia sesión nuevamente.');

      final httpService = HttpService();
      await httpService.loadToken();

      final pendingData = await httpService.get('${ApiConfig.baseUrl}/api/payments?status=Pendiente');
      final pendingList = (pendingData['data'] as List?) ?? [];
      if (pendingList.isNotEmpty) throw Exception('Tenés un pago pendiente. Pagalo antes de registrar otro vehículo.');

      await httpService.post('${ApiConfig.baseUrl}${ApiConfig.carsRegister}', {
        'plate': _plateController.text.trim().toUpperCase(),
        'model': _modelController.text.trim(),
        'brand': _brandController.text.trim(),
        'washType': _selectedWashType,
        'amount': _selectedPrice,
        'scheduledDate': '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}',
        'scheduledTime': '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
        'userId': userId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vehículo registrado'), backgroundColor: AppColors.success));
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      _setError('Tiempo de espera agotado. Verifica tu conexión.');
    } catch (e) {
      _setError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) { setState(() { _errorMessage = message; }); }

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
                  const SizedBox(height: 20),
                  StaggeredFadeIn(index: 1, child: _buildStepIndicator()),
                  const SizedBox(height: 20),
                  _currentStep == 0 ? _buildVehicleStep() : _buildBookingStep(),
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
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF00BCD4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.directions_car, size: 36, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perfil del Vehículo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Completa los datos de tu vehículo', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, 'Vehículo'),
        Expanded(child: Container(height: 2, color: _currentStep >= 1 ? AppColors.primary : AppColors.border)),
        _buildStepDot(1, 'Agendar'),
      ],
    );
  }

  Widget _buildStepDot(int index, String label) {
    final active = _currentStep >= index;
    final done = _currentStep > index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : active ? AppColors.primary.withValues(alpha: 0.15) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: done ? Colors.transparent : active ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : Center(child: Text('${index + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: active ? AppColors.primary : AppColors.textHint))),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: active ? AppColors.primary : AppColors.textHint, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }

  Widget _buildVehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          children: [
            _buildInputField(controller: _plateController, label: 'Placa / Matrícula', icon: Icons.badge_outlined, hint: 'Ej. ABC 123',
              validator: (v) => v == null || v.isEmpty ? 'Ingrese la placa' : null),
            const SizedBox(height: 16),
            _buildInputField(controller: _modelController, label: 'Modelo', icon: Icons.directions_car_outlined, hint: 'Ej. Mustang, Corolla',
              validator: (v) => v == null || v.isEmpty ? 'Ingrese el modelo' : null),
            const SizedBox(height: 16),
            _buildInputField(controller: _brandController, label: 'Marca', icon: Icons.branding_watermark_outlined, hint: 'Ej. Ford, Toyota',
              validator: (v) => v == null || v.isEmpty ? 'Ingrese la marca' : null),
          ],
        ),
        const SizedBox(height: 20),
        _buildCard(
          children: [
            Text('Color', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: List.generate(_colorOptions.length + 1, (i) {
                if (i < _colorOptions.length) {
                  final color = _colorOptions[i];
                  final name = _colorNames[i];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = name),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: color == Colors.white ? Colors.white : color,
                        shape: BoxShape.circle,
                        border: Border.all(color: _selectedColor == name ? AppColors.primary : Colors.grey.shade300, width: _selectedColor == name ? 3 : 1.5),
                        boxShadow: _selectedColor == name ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6)] : null,
                      ),
                      child: color == Colors.white ? Center(child: Icon(Icons.invert_colors, size: 18, color: Colors.grey.shade400)) : null,
                    ),
                  );
                }
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = 'Otro'),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: _selectedColor == 'Otro' ? AppColors.primary : Colors.grey.shade300, width: _selectedColor == 'Otro' ? 3 : 1.5),
                    ),
                    child: const Icon(Icons.colorize, size: 20, color: Colors.grey),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildCard(
          children: [
            Text('Seleccione el Tipo de Lavado', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text('Elegí el servicio que mejor se adapte a tu vehículo', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ..._washServices.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildWashTile(s),
            )),
          ],
        ),
        const SizedBox(height: 20),
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildWashTile(WashService service) {
    final isSelected = _selectedWashType == service.name;
    return GestureDetector(
      onTap: () => setState(() => _selectedWashType = service.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(service.icon, color: isSelected ? AppColors.primary : AppColors.textHint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(service.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isSelected ? AppColors.primary : AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                        ),
                        if (service.badge != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: service.badge == 'Popular' ? Colors.orange.shade50 : AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(service.badge!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: service.badge == 'Popular' ? Colors.orange.shade700 : AppColors.primary)),
                          ),
                        ],
                      ],
                    ),
                    Text(service.description, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('Gs. ${service.price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingStep() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          children: [
            Text('Agendar Lavado', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
                        Text(dateFormat.format(_scheduledDate), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
                      Text('${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (_availableSlots <= 0) ...[
              const SizedBox(height: 8),
              Text('Capacidad completa para esta fecha', style: TextStyle(color: AppColors.error, fontSize: 13)),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _buildCard(
          children: [
            Text('Resumen', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _buildSummaryRow('Servicio $_selectedWashType', _selectedPrice),
            _buildSummaryRow('Subtotal', _selectedPrice, isTotal: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: _availableSlots > 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _availableSlots > 0 ? '$_availableSlots cupos disponibles' : 'Sin cupos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _availableSlots > 0 ? Colors.green.shade700 : Colors.red.shade700),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          ErrorBox(message: _errorMessage!),
        ],
        const SizedBox(height: 20),
        _buildBookingButtons(),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
          Text('Gs. ${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon)),
      validator: validator,
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: GradientButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward,
            onPressed: _nextStep,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Atrás'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Opacity(
            opacity: _availableSlots <= 0 ? 0.4 : 1.0,
            child: GradientButton(
              label: _isLoading ? 'Registrando...' : 'Confirmar Registro',
              icon: Icons.check,
              isLoading: _isLoading,
              onPressed: (_isLoading || _availableSlots <= 0) ? null : _registerCar,
            ),
          ),
        ),
      ],
    );
  }
}

class WashService {
  final String name;
  final double price;
  final IconData icon;
  final String description;
  final String? badge;
  const WashService(this.name, this.price, this.icon, this.description, this.badge);
}
