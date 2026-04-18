import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'gros_divers_channel';
  static const _channelName = 'Gros Divers';
  static const _channelDesc = 'Notifications de l\'application Gros Divers';

  int _notifId = 0;
  int get _nextId => _notifId++;

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          debugPrint('[NotificationService] tapped: ${details.payload}');
        }
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  AndroidNotificationDetails _androidDetails({
    String channelId = _channelId,
    String channelName = _channelName,
    String channelDesc = _channelDesc,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    String? icon,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      icon: icon,
      playSound: true,
      enableVibration: true,
      styleInformation: const DefaultStyleInformation(true, true),
    );
  }

  Future<void> _show({
    required String title,
    required String body,
    String? payload,
    Importance importance = Importance.high,
  }) async {
    try {
      final details = NotificationDetails(
        android: _androidDetails(importance: importance),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(_nextId, title, body, details, payload: payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[NotificationService] error: $e');
    }
  }

  // ─── CLIENT ──────────────────────────────────────────────────────────────

  Future<void> notifyCommandeConfirmee({required int orderId}) => _show(
    title: '✅ Commande confirmée',
    body: 'Votre commande #$orderId a bien été enregistrée.',
    payload: 'order:$orderId',
  );

  Future<void> notifyCommandeEnPreparation({required int orderId}) => _show(
    title: '📦 Commande en préparation',
    body: 'Votre commande #$orderId est en cours de préparation.',
    payload: 'order:$orderId',
  );

  Future<void> notifyCommandePrete({required int orderId}) => _show(
    title: '🚀 Commande prête',
    body: 'Votre commande #$orderId est prête et en attente de livraison.',
    payload: 'order:$orderId',
  );

  Future<void> notifyCommandeLivree({required int orderId}) => _show(
    title: '🎉 Commande livrée !',
    body: 'Votre commande #$orderId a été livrée. Merci pour votre achat !',
    payload: 'order:$orderId',
  );

  Future<void> notifyCommandeAnnulee({required int orderId}) => _show(
    title: '❌ Commande annulée',
    body: 'Votre commande #$orderId a été annulée.',
    payload: 'order:$orderId',
    importance: Importance.defaultImportance,
  );

  // ─── ADMIN & PRÉPARATEUR ──────────────────────────────────────────────────

  Future<void> notifyNouvelleCommande({
    required int orderId,
    required String clientName,
    required double montant,
  }) => _show(
    title: '🛒 Nouvelle commande',
    body:
        '$clientName a passé une commande #$orderId de ${montant.toStringAsFixed(0)} F CFA.',
    payload: 'admin:order:$orderId',
  );

  Future<void> notifyCommandeAAssigner({required int orderId}) => _show(
    title: '📋 Commande à assigner',
    body: 'La commande #$orderId est prête. Assignez un livreur maintenant.',
    payload: 'admin:assign:$orderId',
  );

  Future<void> notifyStockFaible({
    required String productName,
    required int quantity,
  }) => _show(
    title: '⚠️ Stock faible',
    body:
        'Le produit "$productName" n\'a plus que $quantity unité(s) en stock.',
    payload: 'stock:low',
    importance: Importance.defaultImportance,
  );

  // ─── LIVREUR ─────────────────────────────────────────────────────────────

  Future<void> notifyNouvelleDemandelivraison({
    required int orderId,
    required String clientName,
    String? address,
  }) => _show(
    title: '🚚 Nouvelle demande de livraison',
    body: address != null
        ? 'Commande #$orderId pour $clientName — $address'
        : 'Commande #$orderId assignée pour $clientName.',
    payload: 'delivery:$orderId',
  );

  Future<void> notifyLivraisonConfirmee({required int orderId}) => _show(
    title: '✅ Livraison confirmée',
    body: 'La livraison de la commande #$orderId a été validée.',
    payload: 'delivery:done:$orderId',
    importance: Importance.defaultImportance,
  );
}
