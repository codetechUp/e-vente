import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice_model.dart';
import 'supabase_table_service.dart';

class InvoicesService {
  final SupabaseTableService<InvoiceModel> _table;
  final SupabaseClient _client;

  InvoicesService({SupabaseTableService<InvoiceModel>? table})
      : _table = table ??
            SupabaseTableService<InvoiceModel>(
              table: 'invoices',
              primaryKey: 'id',
              fromJson: InvoiceModel.fromJson,
              toJson: (m) => m.toJson(),
            ),
        _client = Supabase.instance.client;

  Future<List<InvoiceModel>> getAll() => _table.getAll(orderBy: 'created_at', ascending: false);

  Future<InvoiceModel?> getById(String id) => _table.getById(id);

  Future<InvoiceModel?> getByOrderId(int orderId) async {
    final row = await _client
        .from('invoices')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();

    if (row == null) return null;
    return InvoiceModel.fromJson((row as Map).cast<String, dynamic>());
  }

  Future<InvoiceModel> create(InvoiceModel model) => _table.create(model);

  Future<String> generateNextInvoiceNumber() async {
    final year = DateTime.now().year;
    final prefix = 'FAC-$year-';

    final response = await _client
        .from('invoices')
        .select('invoice_number')
        .like('invoice_number', '$prefix%')
        .order('invoice_number', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNum = 1;
    if (response != null) {
      final lastNumStr = response['invoice_number'] as String;
      final numPart = lastNumStr.substring(prefix.length);
      final lastNum = int.tryParse(numPart) ?? 0;
      nextNum = lastNum + 1;
    }

    final formattedNum = nextNum.toString().padLeft(5, '0');
    return '$prefix$formattedNum';
  }

  Future<InvoiceModel> getOrCreateInvoiceForOrder(int orderId, String userId) async {
    final existing = await getByOrderId(orderId);
    if (existing != null) return existing;

    final number = await generateNextInvoiceNumber();
    final model = InvoiceModel(
      orderId: orderId,
      invoiceNumber: number,
      createdBy: userId,
    );
    return create(model);
  }
}
