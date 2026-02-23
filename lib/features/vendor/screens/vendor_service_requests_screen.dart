// lib/features/vendor/screens/vendor_service_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/service_request_provider.dart';
import '../../../shared/models/service_request_model.dart';

class VendorServiceRequestsScreen extends ConsumerStatefulWidget {
  const VendorServiceRequestsScreen({super.key});

  @override
  ConsumerState<VendorServiceRequestsScreen> createState() => _VendorServiceRequestsScreenState();
}

class _VendorServiceRequestsScreenState extends ConsumerState<VendorServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['All', 'Pending', 'Quoted', 'In Progress', 'Completed'];
  final List<String?> _statuses = [null, 'pending', 'quoted', 'in_progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadForTab(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForTab(0);
    });
  }

  void _loadForTab(int index) {
    ref.read(vendorServiceRequestsProvider.notifier).loadRequests(
          status: _statuses[index],
          refresh: true,
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorServiceRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Service Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.asMap().entries.map((e) {
            final count = e.key > 0
                ? (state.statusCounts[_statuses[e.key]] ?? 0)
                : state.total;
            return Tab(
              child: Row(
                children: [
                  Text(e.value),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: e.key == _tabController.index
                            ? AppColors.primary
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: e.key == _tabController.index ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.asMap().entries.map((e) {
          return _RequestsList(
            status: _statuses[e.key],
            tabController: _tabController,
            tabIndex: e.key,
          );
        }).toList(),
      ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final String? status;
  final TabController tabController;
  final int tabIndex;

  const _RequestsList({
    required this.status,
    required this.tabController,
    required this.tabIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vendorServiceRequestsProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(vendorServiceRequestsProvider.notifier)
                  .loadRequests(status: status, refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No service requests yet',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Requests from buyers will appear here',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(vendorServiceRequestsProvider.notifier)
          .loadRequests(status: status, refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.requests.length,
        itemBuilder: (context, index) => _RequestCard(request: state.requests[index]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ServiceRequestModel request;

  const _RequestCard({required this.request});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'quoted': return Colors.blue;
      case 'accepted': return Colors.teal;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/vendor/service-requests/${request.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.service?.title ?? 'Service Request',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(request.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(request.status).withOpacity(0.4)),
                    ),
                    child: Text(
                      request.statusLabel,
                      style: TextStyle(
                        color: _statusColor(request.status),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(request.customerName, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(width: 16),
                  if (request.urgency == 'urgent' || request.urgency == 'emergency') ...[
                    Icon(Icons.priority_high, size: 14, color: Colors.red[400]),
                    const SizedBox(width: 2),
                    Text(
                      request.urgency.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: Colors.red[400], fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (request.quotedPrice != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 14, color: AppColors.primary),
                    Text(
                      'Quoted: UGX ${request.quotedPrice!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    request.requestNumber,
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
