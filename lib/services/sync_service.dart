import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:walletwatch/services/expense_database.dart';

class SyncService {
  static final supabase = Supabase.instance.client;

  // ---------------- INTERNET CHECK ----------------
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------- SYNC ALL ----------------
  static Future<void> syncAll() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    if (!await hasInternetConnection()) return;

    await syncExpenses(user.id);
    await syncBudgets(user.id);
    await syncTransfers(user.id);
  }

  // ---------------- EXPENSES ----------------
  static Future<void> syncExpenses(String userId) async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses(userId);

    for (final exp in unsynced) {
      try {
        final response = await supabase
            .from('expenses')
            .insert({
              'uuid': exp['uuid'],
              'user_id': userId,
              'date': exp['date'],
              'shop': exp['shop'],
              'category': exp['category'],
              'items': exp['items'],
              'total': exp['total'],
              'mode': exp['mode'],
              'bank': exp['bank'],
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateExpense(exp['id'], {
          'supabase_id': response['id'],
          'synced': 1,
        });
      } catch (_) {}
    }
  }

  // ---------------- BUDGETS ----------------
  static Future<void> syncBudgets(String userId) async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedBudgets(userId);

    for (final b in unsynced) {
      try {
        final res = await supabase
            .from('budgets')
            .insert({
              'uuid': b['uuid'],
              'user_id': userId,
              'date': b['date'],
              'mode': b['mode'],
              'total': b['total'],
              'bank': b['bank'],
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateBudget(b['id'], {
          'supabase_id': res['id'],
          'synced': 1,
        });
      } catch (_) {}
    }
  }

  // ---------------- TRANSFERS ----------------
  static Future<void> syncTransfers(String userId) async {
    final unsyncedTransfers = await DatabaseHelper.instance
        .getUnsyncedTransfers(userId);

    for (final t in unsyncedTransfers) {
      try {
        final response = await supabase
            .from('transfers')
            .insert({
              'uuid': t['uuid'],
              'user_id': t['user_id'],
              'from_type': t['from_type'],
              'to_type': t['to_type'],
              'from_bank': t['from_bank'],
              'to_bank': t['to_bank'],
              'amount': t['amount'],
              'date': t['date'],
            })
            .select('id')
            .single();

        await DatabaseHelper.instance.updateTransfer(t['id'], {
          'synced': 1,
          'supabase_id': response['id'],
        });
      } catch (e) {
        debugPrint("Transfer Sync Error: $e");
      }
    }
  }
}
