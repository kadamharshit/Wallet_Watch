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
    } catch (e) {
      return false;
    }
  }

  // ---------------- SYNC ALL ----------------
  static Future<void> syncAll() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    //if (!await hasInternetConnection()) return;

    await syncExpenses(user.id);
    await syncBudgets(user.id);
    await syncTransfers(user.id);

    await downloadExpenses(user.id);
    await downloadBudgets(user.id);
    await downloadTransfers(user.id);
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

  static Future<void> downloadExpenses(String userId) async {
    final cloudExpenses = await supabase
        .from('expenses')
        .select()
        .eq('user_id', userId);

    for (final exp in cloudExpenses) {
      await DatabaseHelper.instance.upsertExpenseByUuid({
        'uuid': exp['uuid'],
        'user_id': exp['user_id'],
        'supabase_id': exp['id'],
        'date': exp['date'],
        'shop': exp['shop'],
        'category': exp['category'],
        'items': exp['items'],
        'total': exp['total'],
        'mode': exp['mode'],
        'bank': exp['bank'],
        'synced': 1,
      });
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

  static Future<void> downloadBudgets(String userId) async {
    final cloudBudgets = await supabase
        .from('budgets')
        .select()
        .eq('user_id', userId);

    for (final b in cloudBudgets) {
      await DatabaseHelper.instance.upsertBudgetByUuid({
        'uuid': b['uuid'],
        'user_id': b['user_id'],
        'supabase_id': b['id'],
        'date': b['date'],
        'mode': b['mode'],
        'total': b['total'],
        'bank': b['bank'],
        'synced': 1,
      });
    }
  }

  // ---------------- TRANSFERS ----------------
  static Future<void> syncTransfers(String userId) async {
    final unsyncedTransfers = await DatabaseHelper.instance
        .getUnsyncedTransfers(userId);

    for (final t in unsyncedTransfers) {
      try {
        if (t['supabase_id'] != null) {
          // UPDATE existing transfer
          await supabase
              .from('transfers')
              .update({
                'from_type': t['from_type'],
                'to_type': t['to_type'],
                'from_bank': t['from_bank'],
                'to_bank': t['to_bank'],
                'amount': t['amount'],
              })
              .eq('id', t['supabase_id']);

          await DatabaseHelper.instance.updateTransfer(t['id'], {'synced': 1});
        } else {
          // INSERT new transfer
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
        }
      } catch (e) {
        debugPrint("Transfer Sync Error: $e");
      }
    }
  }

  static Future<void> downloadTransfers(String userId) async {
    final cloudTransfers = await supabase
        .from('transfers')
        .select()
        .eq('user_id', userId);

    for (final t in cloudTransfers) {
      await DatabaseHelper.instance.upsertTransferByUuid({
        'uuid': t['uuid'],
        'user_id': t['user_id'],
        'supabase_id': t['id'],
        'from_type': t['from_type'],
        'to_type': t['to_type'],
        'from_bank': t['from_bank'],
        'to_bank': t['to_bank'],
        'amount': t['amount'],
        'date': t['date'],
        'synced': 1,
      });
    }
  }
}
