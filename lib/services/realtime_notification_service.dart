import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import 'notification_service.dart';

/// Service qui écoute Supabase Realtime pour afficher des notifications
/// à tous les utilisateurs concernés (admin, livreur, client)
class RealtimeNotificationService {
  final SupabaseClient _client;
  RealtimeChannel? _ordersChannel;

  RealtimeNotificationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Démarre l'écoute des changements sur la table orders
  void startListening(AuthProvider authProvider) {
    _ordersChannel?.unsubscribe();

    _ordersChannel = _client
        .channel('orders_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _handleOrderChange(payload, authProvider),
        )
        .subscribe();

    log('[RealtimeNotification] Écoute démarrée');
  }

  void stopListening() {
    _ordersChannel?.unsubscribe();
    log('[RealtimeNotification] Écoute arrêtée');
  }

  Future<void> _handleOrderChange(
    PostgresChangePayload payload,
    AuthProvider authProvider,
  ) async {
    final eventType = payload.eventType;
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    final orderId = newRecord['id'] as int?;
    final status = newRecord['status'] as String?;
    final userId = newRecord['user_id'] as String?;
    final assignedLivreurId = newRecord['assigned_livreur_id'] as String?;
    final currentUserId = authProvider.user?.id;
    final currentUserRole = authProvider.roleName?.toLowerCase();

    if (orderId == null || status == null) return;

    final notif = NotificationService();

    // 1. Nouvelle commande créée → notifier l'admin/préparateur
    if (eventType == PostgresChangeEvent.insert) {
      // Si je suis admin/préparateur, je reçois une notification
      if (currentUserRole == 'admin' || currentUserRole == 'preparateur') {
        final totalPrice = (newRecord['total_price'] as num?)?.toDouble() ?? 0;
        final userName = _extractUserName(newRecord);
        await notif.notifyNouvelleCommande(
          orderId: orderId,
          clientName: userName,
          montant: totalPrice,
        );
      }
      return;
    }

    // 2. Mise à jour du statut
    if (eventType == PostgresChangeEvent.update) {
      final oldStatus = oldRecord['status'] as String?;
      final oldAssignedLivreurId = oldRecord['assigned_livreur_id'] as String?;

      // Changement de statut → notifier le client
      if (oldStatus != status && userId == currentUserId) {
        await _notifyClientStatusChange(notif, orderId, status);
      }

      // Assignation d'un livreur → notifier le livreur
      if (oldAssignedLivreurId != assignedLivreurId &&
          assignedLivreurId == currentUserId) {
        final clientName = _extractUserName(newRecord);
        final address = newRecord['delivery_address'] as String?;
        await notif.notifyNouvelleDemandelivraison(
          orderId: orderId,
          clientName: clientName,
          address: address,
        );
      }
    }
  }

  Future<void> _notifyClientStatusChange(
    NotificationService notif,
    int orderId,
    String status,
  ) async {
    switch (status) {
      case 'preparing':
        await notif.notifyCommandeEnPreparation(orderId: orderId);
        break;
      case 'ready':
        await notif.notifyCommandePrete(orderId: orderId);
        break;
      case 'delivered':
        await notif.notifyCommandeLivree(orderId: orderId);
        break;
      case 'cancelled':
        await notif.notifyCommandeAnnulee(orderId: orderId);
        break;
    }
  }

  String _extractUserName(Map<String, dynamic> record) {
    final users = record['users'] as Map<String, dynamic>?;
    return users?['name'] ?? users?['nom'] ?? 'Client';
  }
}
