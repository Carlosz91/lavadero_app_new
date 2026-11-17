import '../repositories/payment_repository.dart';
import '../services/http_service.dart';

/// Fachada estática sobre [PaymentRepository] (se mantiene por compatibilidad
/// con las pantallas existentes).
class PaymentService {
  static final PaymentRepository _repository = PaymentRepository(HttpService());

  /// Pagos del usuario autenticado.
  static Future<List<Map<String, dynamic>>> getPayments({String? status}) async {
    try {
      return await _repository.getPayments(status: status);
    } catch (e) {
      throw HttpException(friendlyErrorMessage(e));
    }
  }
}
