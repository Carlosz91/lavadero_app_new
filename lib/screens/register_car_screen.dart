import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/http_service.dart';

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
    'Básico',
    'Premium',
    'Completo',
    'Detailing'
  ];
  final Map<String, double> _washPrices = {
    'Básico': 50000,
    'Premium': 80000,
    'Completo': 120000,
    'Detailing': 200000,
  };

  String _selectedWashType = 'Básico';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text = _washPrices[_selectedWashType]!.toStringAsFixed(0);
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

  Future<void> _registerCar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final plate = _plateController.text.trim().toUpperCase();
      final model = _modelController.text.trim();
      final brand = _brandController.text.trim();
      final washType = _selectedWashType;
      final amount = double.parse(_amountController.text.trim());

      if (amount <= 0) throw Exception('El monto debe ser mayor a cero');

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        throw Exception('No se encontró el usuario. Inicia sesión nuevamente.');
      }

      final httpService = HttpService();
      final response = await httpService.post(
        '${ApiConfig.baseUrl}${ApiConfig.carsRegister}',
        {
          'plate': plate,
          'model': model,
          'brand': brand,
          'washType': washType,
          'amount': amount,
          'userId': userId,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? '✅ Vehículo registrado'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      _formKey.currentState?.reset();
      _updateAmount('Básico');

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      _setError('⏰ Tiempo de espera agotado. Verifica tu conexión.');
    } catch (e) {
      _setError('❌ ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      labelStyle: const TextStyle(
          color: Colors.blueAccent, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: Colors.blueAccent, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    TextInputType? inputType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: inputType,
      decoration: _buildInputDecoration(label, icon, hint: hint),
      validator: validator,
    );
  }

  Widget _buildWashOption(String type, double price) {
    final isSelected = _selectedWashType == type;
    return GestureDetector(
      onTap: () => _updateAmount(type),
      child: Card(
        elevation: isSelected ? 8 : 2,
        color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? Colors.blueAccent.withOpacity(0.8)
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.05),
                      Colors.blue.shade50.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blueAccent.withOpacity(0.15)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIcon(type),
                color: isSelected ? Colors.blueAccent : Colors.grey.shade600,
                size: 28,
              ),
            ),
            title: Text(
              type,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.blueAccent : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Gs. ${price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.blueAccent.shade700
                    : Colors.grey.shade600,
              ),
            ),
            trailing: isSelected
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 18),
                  )
                : null,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Vehículo"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Color(0xFFF0F4FF), // azul muy claro suave
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  const Text(
                    'Información del Vehículo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _plateController,
                    label: 'Placa',
                    icon: Icons.confirmation_number,
                    hint: 'ABC123',
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Ingrese la placa';
                      if (value.length < 4) return 'Mínimo 4 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _modelController,
                    label: 'Modelo',
                    icon: Icons.model_training,
                    hint: 'Civic, Corolla...',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Ingrese el modelo'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _brandController,
                    label: 'Marca',
                    icon: Icons.branding_watermark,
                    hint: 'Toyota, Honda...',
                    validator: (value) => value == null || value.isEmpty
                        ? 'Ingrese la marca'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Seleccione el Tipo de Lavado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._washTypes.map(
                    (type) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildWashOption(type, _washPrices[type]!),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _amountController,
                    label: 'Monto (Gs.)',
                    icon: Icons.attach_money,
                    readOnly: true,
                    inputType: TextInputType.number,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBox(_errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButtons(),
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
        gradient: LinearGradient(
          colors: [Colors.blueAccent, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.directions_car, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 12),
          const Text(
            'Registro de Vehículo',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Complete los datos del vehículo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.blue.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.save, size: 22),
              label: Text(
                _isLoading ? 'Registrando...' : 'Registrar Vehículo',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: _isLoading ? null : _registerCar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            label: const Text(
              'Cancelar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: const BorderSide(color: Colors.blueAccent, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
