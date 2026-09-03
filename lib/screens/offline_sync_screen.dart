import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/offline_sale_queue.dart';
import '../state/product_catalog.dart';

class OfflineSyncScreen extends StatelessWidget {
  const OfflineSyncScreen({super.key});

  Future<void> _sync(BuildContext context) async {
    final queue = context.read<OfflineSaleQueue>();
    final synced = await queue.syncAll();
    if (!context.mounted) return;
    if (synced > 0) {
      try {
        await context.read<ProductCatalog>().synchronize(force: true);
      } catch (_) {}
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          queue.pendingCount == 0
              ? 'تمت مزامنة كل المبيعات المعلقة.'
              : 'تمت مزامنة $synced عملية، وبقي ${queue.pendingCount}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<OfflineSaleQueue>();
    return Scaffold(
      appBar: AppBar(title: const Text('المزامنة')),
      body: RefreshIndicator(
        onRefresh: () => _sync(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          children: [
            _SyncHero(queue: queue, onSync: queue.syncing ? null : () => _sync(context)),
            if (queue.lastError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZColors.warningSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0D986)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: ZColors.yellowText),
                    const SizedBox(width: 8),
                    Expanded(child: Text(queue.lastError!, style: const TextStyle(fontSize: 11, color: ZColors.yellowText))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(child: Text('عمليات تنتظر الرفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ZColors.green))),
                Text('${queue.pendingCount}', style: const TextStyle(fontSize: 11, color: ZColors.subtle)),
              ],
            ),
            const SizedBox(height: 10),
            if (queue.items.isEmpty)
              const _SyncEmpty()
            else
              ...queue.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PendingSaleCard(
                      item: item,
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('حذف عملية معلقة؟'),
                            content: const Text('لن تصل هذه العملية إلى الخادم بعد الحذف. استخدم هذا فقط إذا كنت متأكدًا أنها أُدخلت بطريقة أخرى.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
                            ],
                          ),
                        );
                        if (confirmed == true) await queue.remove(item.clientRequestId);
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _SyncHero extends StatelessWidget {
  const _SyncHero({required this.queue, required this.onSync});
  final OfflineSaleQueue queue;
  final VoidCallback? onSync;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF1A3C34), ZColors.green]),
          boxShadow: ZShadow.float,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: ZColors.yellow, borderRadius: BorderRadius.circular(15)), child: Icon(queue.pendingCount == 0 ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded, color: ZColors.green)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(queue.pendingCount == 0 ? 'كل شيء متزامن' : '${queue.pendingCount} عملية تنتظر', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(queue.pendingCount == 0 ? 'لا توجد مبيعات معلقة على هذا الجهاز.' : 'سنرفعها بنفس رقم الطلب لمنع تكرار الفواتير.', style: const TextStyle(fontSize: 10.5, color: Color(0xFFC5D7D2))),
                    ],
                  ),
                ),
              ],
            ),
            if (queue.pendingCount > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: ZColors.yellow, foregroundColor: ZColors.green),
                  onPressed: onSync,
                  icon: queue.syncing ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: ZColors.green)) : const Icon(Icons.sync_rounded),
                  label: Text(queue.syncing ? 'جارٍ المزامنة...' : 'مزامنة الآن'),
                ),
              ),
            ],
          ],
        ),
      );
}

class _PendingSaleCard extends StatelessWidget {
  const _PendingSaleCard({required this.item, required this.onDelete});
  final PendingSale item;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE)), boxShadow: ZShadow.card),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: ZColors.warningSurface, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.schedule_send_rounded, color: ZColors.yellowText)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((item.customerName ?? '').trim().isEmpty ? 'بيع بدون اسم عميل' : item.customerName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${item.items.length} صنف • ${item.total.toStringAsFixed(0)} ر.ي', style: const TextStyle(fontSize: 11, color: ZColors.muted)),
                  const SizedBox(height: 2),
                  Text(DateFormat('yyyy/MM/dd • HH:mm').format(item.createdAt), style: const TextStyle(fontSize: 9.5, color: ZColors.subtle)),
                ],
              ),
            ),
            IconButton(tooltip: 'حذف العملية المعلقة', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: ZColors.danger)),
          ],
        ),
      );
}

class _SyncEmpty extends StatelessWidget {
  const _SyncEmpty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E8EE))),
        child: const Column(children: [Icon(Icons.cloud_done_outlined, size: 38, color: ZColors.success), SizedBox(height: 9), Text('لا توجد عمليات معلقة', style: TextStyle(fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('مبيعاتك الحالية محفوظة على الخادم.', style: TextStyle(fontSize: 10.5, color: ZColors.muted))]),
      );
}
