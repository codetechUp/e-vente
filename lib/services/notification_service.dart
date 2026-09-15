import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  
  FirebaseMessaging? get _fcm => kIsWeb ? null : FirebaseMessaging.instance;

  static const _channelId = 'gros_divers_channel';
  static const _channelName = 'Gros Divers';
  static const _channelDesc = 'Notifications de l\'application Gros Divers';

  int _notifId = 0;
  int get _nextId => _notifId++;

  Future<void> init() async {
    if (kIsWeb) {
      // Les notifications locales natives Android/iOS et FCM ne s'appliquent pas sur le Web
      return;
    }
    try {
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

      // Initialiser FCM après les notifications locales
      await initFcm();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Error initializing notifications: $e');
      }
    }
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

  // ─── FIREBASE CLOUD MESSAGING (FCM) ──────────────────────────────────────────

  Future<void> initFcm() async {
    final fcmInstance = _fcm;
    if (kIsWeb || fcmInstance == null) return;
    try {
      // 1. Demander les permissions (requis pour iOS, bonne pratique pour Android)
      final settings = await fcmInstance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('[NotificationService] FCM Permission Status: ${settings.authorizationStatus}');
      }

      // Récupérer et afficher le token FCM pour débogage
      try {
        final token = await fcmInstance.getToken();
        if (kDebugMode) {
          debugPrint('[NotificationService] FCM Token: $token');
        }
      } catch (tokenError) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Error getting FCM Token: $tokenError');
        }
      }

      fcmInstance.onTokenRefresh.listen((token) {
        if (kDebugMode) {
          debugPrint('[NotificationService] FCM Token refreshed: $token');
        }
      });

      // 2. S'abonner au topic "all" pour recevoir les diffusions globales
      _subscribeToTopicWithRetry('all');

      // 3. Écouter les messages reçus en premier plan (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[NotificationService] Foreground notification received: ${message.messageId}');
        }

        final notification = message.notification;
        if (notification != null) {
          String? payload;
          if (message.data.isNotEmpty) {
            if (message.data.containsKey('productId')) {
              payload = 'product:${message.data['productId']}';
            }
          }
          _show(
            title: notification.title ?? '',
            body: notification.body ?? '',
            payload: payload,
          );
        }
      });

      // 4. Écouter l'ouverture de l'application via une notification en arrière-plan
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('[NotificationService] App opened via notification: ${message.messageId}');
        }
        _handleNotificationClick(message.data);
      });

      // 5. Vérifier si l'application a été ouverte via une notification depuis un état complètement fermé
      final initialMessage = await fcmInstance.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint('[NotificationService] App opened from terminated state via notification: ${initialMessage.messageId}');
        }
        _handleNotificationClick(initialMessage.data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Error initializing FCM: $e');
      }
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('[NotificationService] Handling notification click: $data');
    }
    // Si la notification contient un productId, nous pourrons naviguer vers les détails du produit
    final productId = data['productId'];
    if (productId != null) {
      debugPrint('[NotificationService] Navigate to product ID: $productId');
    }
  }

  Future<void> _subscribeToTopicWithRetry(String topic) async {
    final fcmInstance = _fcm;
    if (kIsWeb || fcmInstance == null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await fcmInstance.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) {
            debugPrint('[NotificationService] APNS token not set yet. Will retry subscribing to $topic in 3 seconds...');
          }
          Future.delayed(
            const Duration(seconds: 3),
            () => _subscribeToTopicWithRetry(topic),
          );
          return;
        }
      }
      await fcmInstance.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('[NotificationService] Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] Error subscribing to topic $topic: $e');
      }
    }
  }
}
