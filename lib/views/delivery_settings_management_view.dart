import 'package:flutter/material.dart';
import '../models/delivery_setting_model.dart';
import '../services/delivery_settings_service.dart';
import '../utils/constants/app_colors.dart';
import '../utils/constants/app_sizes.dart';
import '../widgets/app_button.dart';

class DeliverySettingsManagementView extends StatefulWidget {
  const DeliverySettingsManagementView({super.key});

  @override
  State<DeliverySettingsManagementView> createState() =>
      _DeliverySettingsManagementViewState();
}

class _DeliverySettingsManagementViewState
    extends State<DeliverySettingsManagementView> {
  final _service = DeliverySettingsService();
  late Future<List<DeliverySettingModel>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.getAll();
  }

  Future<void> _toggleDay(DeliverySettingModel setting) async {
    final id = setting.id;
    if (id == null) return;
    try {
      await _service.update(id, {'is_active': !setting.isActive});
      setState(() {
        _load();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _editTimeSlots(DeliverySettingModel setting) async {
    final controller = TextEditingController(text: setting.timeSlots.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Créneaux pour ${setting.day}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Séparez les créneaux par des virgules (ex: 08h-12h, 14h-18h)',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Créneaux'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null && setting.id != null) {
      final slots = result
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      try {
        await _service.update(setting.id!, {'time_slots': slots});
        setState(() {
          _load();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Planning de livraison',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder<List<DeliverySettingModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final settings = snapshot.data ?? [];
          if (settings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aucun réglage trouvé.'),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Initialiser les jours',
                    onPressed: () async {
                      await _service.initializeDefaultSettings();
                      setState(() {
                        _load();
                      });
                    },
                  ),
                ],
              ),
            );
          }

          settings.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.padding),
            itemCount: settings.length,
            itemBuilder: (context, index) {
              final s = settings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text(
                    s.day,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    s.isActive
                        ? (s.timeSlots.isEmpty
                            ? 'Aucun créneau'
                            : s.timeSlots.join(', '))
                        : 'Désactivé',
                    style: TextStyle(
                      color: s.isActive ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: s.isActive,
                        onChanged: (_) => _toggleDay(s),
                        activeColor: AppColors.accent,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        onPressed: s.isActive ? () => _editTimeSlots(s) : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
