import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_setting_model.dart';
import 'supabase_table_service.dart';

class DeliverySettingsService extends SupabaseTableService<DeliverySettingModel> {
  DeliverySettingsService()
      : super(
          table: 'delivery_settings',
          primaryKey: 'id',
          fromJson: DeliverySettingModel.fromJson,
          toJson: (item) => item.toJson(),
        );

  Future<List<DeliverySettingModel>> getActiveSettings() async {
    final rows = await Supabase.instance.client
        .from(table)
        .select()
        .eq('is_active', true)
        .order('day_index', ascending: true);
    return (rows as List).map((e) => fromJson(e)).toList();
  }

  Future<void> initializeDefaultSettings() async {
    final existing = await getAll();
    if (existing.isNotEmpty) return;

    final defaults = [
      DeliverySettingModel(day: 'Lundi', dayIndex: 1, timeSlots: ['9h - 19h']),
      DeliverySettingModel(day: 'Mardi', dayIndex: 2, timeSlots: ['9h - 19h']),
      DeliverySettingModel(day: 'Mercredi', dayIndex: 3, timeSlots: ['9h - 19h']),
      DeliverySettingModel(day: 'Jeudi', dayIndex: 4, timeSlots: ['9h - 19h']),
      DeliverySettingModel(day: 'Vendredi', dayIndex: 5, timeSlots: ['9h - 19h']),
      DeliverySettingModel(day: 'Samedi', dayIndex: 6, timeSlots: ['9h - 19h'], isActive: false),
      DeliverySettingModel(day: 'Dimanche', dayIndex: 7, timeSlots: ['9h - 19h'], isActive: false),
    ];

    for (final s in defaults) {
      await create(s);
    }
  }
}
