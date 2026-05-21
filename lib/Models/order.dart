class Order {
  String id;
  String userId;
  String vehicleId;
  String status;
  DateTime date;

  Order({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.status,
    required this.date,
  });
}
