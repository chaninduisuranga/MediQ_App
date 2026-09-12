import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/admin_user_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<AdminUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await AdminService.getUsers(search: _searchController.text);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _users = result['users'] as List<AdminUser>;
        _total = (result['total'] as num?)?.toInt() ?? _users.length;
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadUsers);
  }

  Future<void> _updateUser(AdminUser user,
      {String? role, String? status}) async {
    final result =
        await AdminService.updateUser(user.id, role: role, status: status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] as String? ?? 'User updated')),
    );
    if (result['success'] == true) await _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh users',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Name, NIC, phone, or user ID',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Text('$_total users',
                style: const TextStyle(color: AppTheme.mutedText)),
            const SizedBox(height: 10),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildMessage(_errorMessage!, Icons.error_outline_rounded)
            else if (_users.isEmpty)
              _buildMessage('No users found', Icons.people_outline_rounded)
            else
              ..._users.map(_buildUserCard),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                  child: Text('${user.id}',
                      style: const TextStyle(color: AppTheme.primaryTeal)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _buildStatusBadge(user.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetail('NIC', user.nic),
            _buildDetail('Phone', user.phone),
            _buildDetail('Created', _formatDate(user.createdAt)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: user.role,
                    decoration:
                        const InputDecoration(labelText: 'Role', isDense: true),
                    items: const ['PATIENT', 'DOCTOR', 'STAFF', 'ADMIN']
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (role) {
                      if (role != null && role != user.role) {
                        _updateUser(user, role: role);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: user.status,
                    decoration: const InputDecoration(
                        labelText: 'Status', isDense: true),
                    items: const ['ACTIVE', 'INACTIVE', 'SUSPENDED']
                        .map((status) => DropdownMenuItem(
                            value: status, child: Text(status)))
                        .toList(),
                    onChanged: (status) {
                      if (status != null && status != user.status) {
                        _updateUser(user, status: status);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value',
          style: const TextStyle(color: AppTheme.mutedText)),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = status == 'ACTIVE'
        ? Colors.green
        : status == 'SUSPENDED'
            ? Colors.red
            : Colors.orange;
    return Chip(
      label: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.mutedText),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
