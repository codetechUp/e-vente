import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_model.dart';
import 'supabase_table_service.dart';

class DeliveriesService {
  final SupabaseTableService<DeliveryModel> _table;
  final SupabaseClient _client;

  DeliveriesService({SupabaseTableService<DeliveryModel>? table})
    : _table =
          table ??
          SupabaseTableService<DeliveryModel>(
            table: 'deliveries',
            primaryKey: 'id',
            fromJson: DeliveryModel.fromJson,
            toJson: (m) => m.toJson(),
          ),
      _client = Supabase.instance.client;

  Future<List<DeliveryModel>> getAll() async {
    final rows = await _client
        .from('deliveries')
        .select('''
          *, 
          orders!inner(
            delivery_address, 
            total_price,
            user_id,
            users(name, phone, email),
            order_items(
              id,
              quantity,
              products(name, image_url)
            )
          )
        ''')
        .order('id');

    return (rows as List).map((row) {
      final orderData = row['orders'] as Map?;
      final deliveryAddress = orderData?['delivery_address'] as String?;
      final totalPrice = orderData?['total_price'];
      final orderItems = orderData?['order_items'] as List?;
      final userData = orderData?['users'] as Map?;

      return DeliveryModel.fromJson({
        ...row as Map<String, dynamic>,
        'delivery_address': deliveryAddress,
        'total_price': totalPrice,
        'order_items': orderItems,
        'customer_name': userData?['name'] as String?,
        'customer_phone': userData?['phone'] as String?,
        'customer_email': userData?['email'] as String?,
      });
    }).toList();
  }

  Future<DeliveryModel?> getById(int id) => _table.getById(id);

  Future<DeliveryModel> create(DeliveryModel model) => _table.create(model);

  Future<DeliveryModel> updateById(int id, Map<String, dynamic> patch) =>
      _table.update(id, patch);

  Future<void> deleteById(int id) => _table.delete(id);
}
