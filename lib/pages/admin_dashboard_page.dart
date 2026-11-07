import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/catalog.dart' show allCategories, categoriesMatch;
import '../models/product.dart';
import '../services/admin_api_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../widgets/product_image.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _productCategories = [];
  bool _loading = true;
  bool _showSuspended = false;
  String? _selectedProductCategory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _load();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        adminApiService.getUsers(),
        adminApiService.getOrders(),
        appState.refreshProducts(),
        adminApiService.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<Map<String, dynamic>>;
        _orders = results[1] as List<Map<String, dynamic>>;
        _productCategories = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _canonicalProductCategory(String category) {
    for (final knownCategory in allCategories) {
      if (categoriesMatch(category, knownCategory)) return knownCategory;
    }
    return category.trim();
  }

  Widget _productCategoryFilter(
    Map<String, dynamic> category,
    List<Product> products,
  ) {
    final name = category['name'] as String;
    final published = category['is_published'] == true;
    final count = products
        .where((product) => categoriesMatch(product.category, name))
        .length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          label: Text('$name ($count)${published ? '' : ' · Brouillon'}'),
          selected: _selectedProductCategory == name,
          onSelected: (_) => setState(() {
            _selectedProductCategory = name;
          }),
        ),
        if (!published) ...[
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Publier $name',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.publish_outlined),
            onPressed: () => _publishProductCategory(category),
          ),
        ],
      ],
    );
  }

  Future<void> _addProductCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
            },
            child: const Text('Créer le brouillon'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;

    try {
      await adminApiService.createCategory(name);
      await _load();
      if (mounted) _showMessage('Catégorie créée en brouillon.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _publishProductCategory(Map<String, dynamic> category) async {
    final id = (category['id'] as num).toInt();
    final name = category['name'] as String;
    try {
      await adminApiService.setCategoryPublished(id, true);
      await appState.refreshCategories();
      await _load();
      if (mounted) _showMessage('Catégorie « $name » publiée.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _editUser([Map<String, dynamic>? user]) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _UserEditor(user: user),
    );
    if (values == null) return;
    try {
      if (user == null) {
        await adminApiService.createUser(values);
      } else {
        await adminApiService.updateUser(
          int.parse(user['id'] as String),
          values,
        );
      }
      await _load();
      if (mounted) _showMessage('Utilisateur enregistré.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await _confirm(
      'Supprimer ${user['prenom']} ${user['nom']} ?',
    );
    if (!confirmed) return;
    try {
      await adminApiService.deleteUser(int.parse(user['id'] as String));
      await _load();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _setUserActive(Map<String, dynamic> user, bool isActive) async {
    final action = isActive ? 'réactiver' : 'suspendre';
    if (!await _confirm(
      'Veux-tu vraiment $action ${user['prenom']} ${user['nom']} ?',
    )) {
      return;
    }
    try {
      await adminApiService.updateUser(int.parse(user['id'].toString()), {
        'nom': user['nom'],
        'prenom': user['prenom'],
        'birth_date': user['birthDate'],
        'phone': user['phone'],
        'email': user['email'],
        'username': user['username'],
        'role': user['isAdmin'] == true ? 'admin' : 'user',
        'is_active': isActive,
      });
      await _load();
      if (mounted) {
        _showMessage(isActive ? 'Compte réactivé.' : 'Compte suspendu.');
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _showUserHistory(Map<String, dynamic> user) async {
    try {
      final history = await adminApiService.getUserHistory(
        int.parse(user['id'].toString()),
      );
      if (!mounted) return;
      final logins = history['logins'] as List<dynamic>? ?? const [];
      final actions = history['actions'] as List<dynamic>? ?? const [];
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Historique — ${user['prenom']} ${user['nom']}'),
          content: SizedBox(
            width: 520,
            height: 480,
            child: ListView(
              children: [
                Text(
                  'Connexions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (logins.isEmpty)
                  const ListTile(title: Text('Aucune connexion enregistrée.')),
                for (final entry in logins)
                  ListTile(
                    leading: Icon(
                      _isSuccessfulLogin(entry['succeeded'])
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      color: _isSuccessfulLogin(entry['succeeded'])
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(
                      _isSuccessfulLogin(entry['succeeded'])
                          ? 'Connexion réussie'
                          : 'Échec de connexion',
                    ),
                    subtitle: Text(_displayDate(entry['occurred_at'])),
                  ),
                const Divider(),
                Text(
                  'Actions administrateur',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (actions.isEmpty)
                  const ListTile(title: Text('Aucune action enregistrée.')),
                for (final entry in actions)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: Text(_actionLabel(entry['action'] as String?)),
                    subtitle: Text(
                      '${_displayDate(entry['occurred_at'])} · '
                      'par ${entry['admin_prenom'] ?? ''} '
                      '${entry['admin_nom'] ?? 'administrateur supprimé'}'
                      '${_actionDetails(entry['details'])}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _editProduct([Product? product]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductEditor(product: product),
    );
    if (saved == true) {
      try {
        await _load();
      } on ApiException catch (error) {
        if (mounted) _showMessage(error.message);
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    if (!await _confirm('Supprimer « ${product.name} » ?')) return;
    try {
      await adminApiService.deleteProduct(product.id);
      await _load();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _changeOrderStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    try {
      await adminApiService.updateOrderStatus(
        int.parse(order['id'].toString()),
        status,
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administration'),
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: [
          Tab(icon: Icon(Icons.people_outline), text: 'Utilisateurs'),
          Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Articles'),
          Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Commandes'),
        ],
      ),
    ),
    floatingActionButton: _tabController.index == 2
        ? null
        : FloatingActionButton.extended(
            onPressed: () =>
                _tabController.index == 0 ? _editUser() : _editProduct(),
            icon: const Icon(Icons.add),
            label: Text(
              _tabController.index == 0
                  ? 'Ajouter utilisateur'
                  : 'Ajouter article',
            ),
          ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          )
        : TabBarView(
            controller: _tabController,
            children: [_usersTab(), _productsTab(), _ordersTab()],
          ),
  );

  Widget _usersTab() => LayoutBuilder(
    builder: (context, constraints) {
      final suspendedCount = _users
          .where((user) => user['isActive'] != true)
          .length;
      final users =
          (_showSuspended
                ? _users.where((user) => user['isActive'] != true).toList()
                : _users.where((user) => user['isActive'] == true).toList())
            ..sort((a, b) {
              final adminOrder = (b['isAdmin'] == true ? 1 : 0).compareTo(
                a['isAdmin'] == true ? 1 : 0,
              );
              if (adminOrder != 0) return adminOrder;
              return int.parse(a['id'].toString())
                  .compareTo(int.parse(b['id'].toString()));
            });
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 96),
          children: [
            Text(
              'Gestion des utilisateurs',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_users.length} compte(s) enregistré(s)',
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _showSuspended = !_showSuspended),
                  icon: Icon(
                    _showSuspended
                        ? Icons.people_outline
                        : Icons.delete_outline,
                  ),
                  label: Text('Suspendus ($suspendedCount)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF315A9F),
                    backgroundColor: const Color(0xFFE4EBF8),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              color: Colors.white,
              elevation: 2,
              shadowColor: const Color(0x18000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE8ECF2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: users.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _showSuspended
                              ? 'Aucun compte suspendu.'
                              : 'Aucun utilisateur enregistré.',
                          style: const TextStyle(color: Color(0xFF667085)),
                        ),
                      ),
                    )
                  : constraints.maxWidth >= 760
                  ? _desktopUserTable(users)
                  : _compactUserList(users),
            ),
          ],
        ),
      );
    },
  );

  Widget _desktopUserTable(List<Map<String, dynamic>> users) {
    const widths = [210.0, 150.0, 112.0, 82.0, 205.0, 168.0];
    const headings = [
      'Utilisateur',
      'Contact',
      'Rôle',
      'Statut',
      'Historique des connexions',
      'Actions',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: widths.reduce((a, b) => a + b) + 24,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
              child: Row(
                children: [
                  for (var i = 0; i < headings.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          headings[i],
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            for (final user in users) ...[
              _desktopUserRow(user, widths),
              const Divider(height: 1, indent: 12, endIndent: 12),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _desktopUserRow(Map<String, dynamic> user, List<double> widths) {
    final admin = user['isAdmin'] == true;
    final isActive = user['isActive'] == true;
    final count =
        int.tryParse(user['successful_login_count']?.toString() ?? '') ?? 0;
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widths[0],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['prenom']} ${user['nom']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user['email'] as String? ?? '',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inscrit le ${_displayDate(user['created_at'])}',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: widths[1],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['username'] as String? ?? ''),
                    const SizedBox(height: 3),
                    Text(
                      user['phone'] as String? ?? '',
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: widths[2],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _userBadge(
                  admin ? 'Administrateur' : 'Utilisateur',
                  admin ? const Color(0xFFFFE9C2) : const Color(0xFFDDE8FC),
                  admin ? const Color(0xFF8A4B00) : const Color(0xFF244D8F),
                ),
              ),
            ),
            SizedBox(
              width: widths[3],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _userBadge(
                  isActive ? 'Actif' : 'Suspendu',
                  isActive ? const Color(0xFFD8F0DF) : const Color(0xFFFAD9DC),
                  isActive ? const Color(0xFF176B38) : const Color(0xFF9B2633),
                ),
              ),
            ),
            SizedBox(
              width: widths[4],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: count == 0
                    ? const Text(
                        'Aucune connexion',
                        style: TextStyle(color: Color(0xFF667085)),
                      )
                    : TextButton.icon(
                        onPressed: () => _showUserHistory(user),
                        icon: const Icon(Icons.arrow_right, size: 20),
                        label: Text('$count connexion${count > 1 ? 's' : ''}'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF315A9F),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: widths[5],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _userActionButton(
                      'Modifier',
                      const Color(0xFFE8EDF6),
                      const Color(0xFF244D8F),
                      () => _editUser(user),
                    ),
                    if (user['id'] != authService.currentUser?.id)
                      _userActionButton(
                        isActive ? 'Suspendre' : 'Réactiver',
                        const Color(0xFFFFE9C2),
                        const Color(0xFF8A4B00),
                        () => _setUserActive(user, !isActive),
                      ),
                    if (user['id'] != authService.currentUser?.id)
                      _userActionButton(
                        'Supprimer',
                        const Color(0xFFFAD9DC),
                        const Color(0xFF9B2633),
                        () => _deleteUser(user),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactUserList(List<Map<String, dynamic>> users) => Column(
    children: [
      for (final user in users)
        _CompactAdminUserCard(
          user: user,
          onEdit: () => _editUser(user),
          onHistory: () => _showUserHistory(user),
          onToggleStatus: () => _setUserActive(user, user['isActive'] != true),
          onDelete: () => _deleteUser(user),
          canManage: user['id'] != authService.currentUser?.id,
        ),
    ],
  );

  Widget _userBadge(String label, Color background, Color foreground) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _userActionButton(
    String label,
    Color background,
    Color foreground,
    VoidCallback onPressed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: SizedBox(
      width: 112,
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    ),
  );

  Widget _productsTab() {
    final sortedProducts = List<Product>.of(appState.products)
      ..sort((first, second) {
        final categoryOrder = _canonicalProductCategory(first.category)
            .toLowerCase()
            .compareTo(
              _canonicalProductCategory(second.category).toLowerCase(),
            );
        if (categoryOrder != 0) return categoryOrder;
        return first.name.toLowerCase().compareTo(second.name.toLowerCase());
      });
    final categories = List<Map<String, dynamic>>.of(_productCategories)
      ..sort(
        (first, second) => _canonicalProductCategory(first['name'] as String)
            .toLowerCase()
            .compareTo(
              _canonicalProductCategory(second['name'] as String).toLowerCase(),
            ),
      );
    final visibleProducts = _selectedProductCategory == null
        ? sortedProducts
        : sortedProducts
              .where(
                (product) => categoriesMatch(
                  product.category,
                  _selectedProductCategory!,
                ),
              )
              .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Catégories',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${visibleProducts.length} article(s)',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('Tous (${appState.products.length})'),
                  selected: _selectedProductCategory == null,
                  onSelected: (_) => setState(() {
                    _selectedProductCategory = null;
                  }),
                ),
                for (final category in categories)
                  _productCategoryFilter(category, sortedProducts),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter une catégorie'),
                  onPressed: _addProductCategory,
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          if (visibleProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucun article dans cette catégorie.')),
            ),
          for (final product in visibleProducts)
            ListTile(
              leading: SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ProductImage(product, iconSize: 26),
                ),
              ),
              title: Text(product.name),
              subtitle: Text(
                '${product.category} · ${euro(product.finalPrice)} · Stock : ${product.stock}',
              ),
              onTap: () => _editProduct(product),
              trailing: IconButton(
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteProduct(product),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ordersTab() => RefreshIndicator(
    onRefresh: _load,
    child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final items = order['items'] as List<dynamic>? ?? const [];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order['number']} · ${euro(double.parse(order['total'].toString()))}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${order['prenom']} ${order['nom']} · ${order['email']}'),
                if ((order['shipping_address'] as String? ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Livraison : ${order['shipping_prenom']} '
                      '${order['shipping_nom']}, '
                      '${order['shipping_address']}, '
                      '${order['shipping_postal_code']} '
                      '${order['shipping_city']}',
                    ),
                  ),
                const SizedBox(height: 8),
                for (final item in items)
                  Text(
                    '${item['product_name']}'
                    '${(item['color'] as String? ?? '').isEmpty ? '' : ' · ${item['color']}'}'
                    ' × ${item['quantity']}',
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: order['status'] as String,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items:
                      const ['En préparation', 'Expédiée', 'Livrée', 'Annulée']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                  onChanged: (status) {
                    if (status != null && status != order['status']) {
                      _changeOrderStatus(order, status);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

bool _isSuccessfulLogin(Object? value) =>
    value == true || value.toString() == '1';

String _displayDate(Object? value) {
  if (value == null || value.toString().isEmpty) return 'Jamais';
  final date = DateTime.tryParse(value.toString().replaceFirst(' ', 'T'));
  if (date == null) return value.toString();
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _actionLabel(String? action) => switch (action) {
  'created' => 'Compte créé',
  'updated' => 'Compte modifié',
  'suspended' => 'Compte suspendu',
  'reactivated' => 'Compte réactivé',
  'role_changed' => 'Rôle modifié',
  'deleted' => 'Compte supprimé',
  _ => action ?? 'Action administrateur',
};

String _actionDetails(Object? value) {
  if (value is! Map<String, dynamic>) return '';
  final changed = value['changed_fields'];
  if (changed is! List || changed.isEmpty) return '';
  const labels = {
    'nom': 'nom',
    'prenom': 'prénom',
    'birth_date': 'date de naissance',
    'phone': 'téléphone',
    'email': 'e-mail',
    'username': 'identifiant',
    'role': 'rôle',
    'status': 'statut',
    'password': 'mot de passe',
  };
  final fields = changed.map((field) => labels[field] ?? '$field').join(', ');
  return ' · modifié : $fields';
}

class _CompactAdminUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onHistory;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final bool canManage;

  const _CompactAdminUserCard({
    required this.user,
    required this.onEdit,
    required this.onHistory,
    required this.onToggleStatus,
    required this.onDelete,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['isActive'] == true;
    final isAdmin = user['isAdmin'] == true;
    final loginCount =
        int.tryParse(user['successful_login_count']?.toString() ?? '') ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${user['prenom']} ${user['nom']}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            user['email'] as String? ?? '',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text('Contact : ${user['username']} · ${user['phone']}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _compactBadge(
                isAdmin ? 'Administrateur' : 'Utilisateur',
                isAdmin ? const Color(0xFFFFE9C2) : const Color(0xFFDDE8FC),
                isAdmin ? const Color(0xFF8A4B00) : const Color(0xFF244D8F),
              ),
              _compactBadge(
                isActive ? 'Actif' : 'Suspendu',
                isActive ? const Color(0xFFD8F0DF) : const Color(0xFFFAD9DC),
                isActive ? const Color(0xFF176B38) : const Color(0xFF9B2633),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Inscrit le ${_displayDate(user['created_at'])}',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (loginCount == 0)
            const Text(
              'Aucune connexion',
              style: TextStyle(color: Color(0xFF667085)),
            )
          else
            TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.arrow_right, size: 20),
              label: Text('$loginCount connexion${loginCount > 1 ? 's' : ''}'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF315A9F),
                padding: EdgeInsets.zero,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _compactAction(
                'Modifier',
                const Color(0xFFE8EDF6),
                const Color(0xFF244D8F),
                onEdit,
              ),
              if (canManage)
                _compactAction(
                  isActive ? 'Suspendre' : 'Réactiver',
                  const Color(0xFFFFE9C2),
                  const Color(0xFF8A4B00),
                  onToggleStatus,
                ),
              if (canManage)
                _compactAction(
                  'Supprimer',
                  const Color(0xFFFAD9DC),
                  const Color(0xFF9B2633),
                  onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactBadge(String label, Color background, Color foreground) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(label, style: TextStyle(color: foreground, fontSize: 12)),
        ),
      );

  Widget _compactAction(
    String label,
    Color background,
    Color foreground,
    VoidCallback onPressed,
  ) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    child: Text(label),
  );
}

const _lightViolet = Color(0xFFE9E4FF);

class _UserEditor extends StatefulWidget {
  final Map<String, dynamic>? user;

  const _UserEditor({this.user});

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.user?['nom'] as String?);
  late final _prenom = TextEditingController(
    text: widget.user?['prenom'] as String?,
  );
  late final _birthDate = TextEditingController(
    text: widget.user?['birthDate'] as String?,
  );
  late final _phone = TextEditingController(
    text: widget.user?['phone'] as String?,
  );
  late final _email = TextEditingController(
    text: widget.user?['email'] as String?,
  );
  late final _username = TextEditingController(
    text: widget.user?['username'] as String?,
  );
  final _password = TextEditingController();
  late bool _admin = widget.user?['isAdmin'] as bool? ?? false;
  late bool _isActive = widget.user?['isActive'] as bool? ?? true;

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _birthDate.dispose();
    _phone.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final current = DateTime.tryParse(_birthDate.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Sélectionne la date de naissance',
    );
    if (selected == null || !mounted) return;
    _birthDate.text =
        '${selected.year.toString().padLeft(4, '0')}-'
        '${selected.month.toString().padLeft(2, '0')}-'
        '${selected.day.toString().padLeft(2, '0')}';
  }

  String? _validateBirthDate(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final dateText = value!.trim();
    final date = DateTime.tryParse(dateText);
    if (date == null ||
        dateText !=
            '${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}') {
      return 'Choisis une date valide avec le calendrier';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.user == null ? 'Ajouter un utilisateur' : 'Modifier le compte',
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_prenom, 'Prénom'),
              _field(_nom, 'Nom'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: _birthDate,
                  readOnly: true,
                  onTap: _selectBirthDate,
                  decoration: const InputDecoration(
                    labelText: 'Date de naissance',
                    hintText: 'Choisir une date',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: _validateBirthDate,
                ),
              ),
              _field(_phone, 'Téléphone'),
              _field(
                _email,
                'E-mail',
                keyboardType: TextInputType.emailAddress,
              ),
              _field(_username, 'Identifiant'),
              _field(
                _password,
                widget.user == null
                    ? 'Mot de passe (8 caractères minimum)'
                    : 'Nouveau mot de passe (facultatif)',
                obscure: true,
                required: widget.user == null,
              ),
              DropdownButtonFormField<bool>(
                initialValue: _admin,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('Utilisateur')),
                  DropdownMenuItem(value: true, child: Text('Administrateur')),
                ],
                onChanged: (value) => setState(() => _admin = value ?? false),
              ),
              DropdownButtonFormField<bool>(
                initialValue: _isActive,
                decoration: const InputDecoration(
                  labelText: 'Statut du compte',
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Actif')),
                  DropdownMenuItem(value: false, child: Text('Suspendu')),
                ],
                onChanged: (value) => setState(() => _isActive = value ?? true),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, {
            'nom': _nom.text.trim(),
            'prenom': _prenom.text.trim(),
            'birth_date': _birthDate.text.trim(),
            'phone': _phone.text.trim(),
            'email': _email.text.trim(),
            'username': _username.text.trim(),
            'role': _admin ? 'admin' : 'user',
            'is_active': _isActive,
            if (_password.text.isNotEmpty) 'password': _password.text,
          });
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
    bool required = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && _required(value) != null) return 'Champ obligatoire';
        if (obscure && value != null && value.isNotEmpty && value.length < 8) {
          return '8 caractères minimum';
        }
        return null;
      },
    ),
  );
}

class _ProductEditor extends StatefulWidget {
  final Product? product;

  const _ProductEditor({this.product});

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _brand = TextEditingController(text: widget.product?.brand ?? '');
  late final _category = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product?.price.toString() ?? '',
  );
  late final _promo = TextEditingController(
    text: widget.product?.promoPrice?.toString() ?? '',
  );
  late final _stock = TextEditingController(
    text: widget.product?.stock.toString() ?? '0',
  );
  late final _colorStock = TextEditingController(
    text:
        widget.product?.colorStock.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n') ??
        '',
  );
  late final _imageUrl = TextEditingController();
  late final _specs = TextEditingController(
    text: jsonEncode(widget.product?.specs ?? const <String, String>{}),
  );
  late final List<String> _imageUrls = [...?widget.product?.galleryImageUrls];
  final List<XFile> _images = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _promo.dispose();
    _stock.dispose();
    _colorStock.dispose();
    _imageUrl.dispose();
    _specs.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final images = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (!mounted || images.isEmpty) return;
    final available =
        5 -
        _imageUrls.length -
        _images.length -
        (_imageUrl.text.trim().isEmpty ? 0 : 1);
    if (images.length > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('5 photos maximum par article.')),
      );
      return;
    }
    setState(() => _images.addAll(images));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final pendingImageCount =
        _imageUrls.length +
        _images.length +
        (_imageUrl.text.trim().isEmpty ? 0 : 1);
    if (pendingImageCount > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('5 photos maximum par article.')),
      );
      return;
    }

    Map<String, dynamic> specs;
    try {
      final decoded = jsonDecode(_specs.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }
      specs = decoded;
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caractéristiques : JSON invalide.')),
      );
      return;
    }

    final colorStock = <String, int>{};
    for (final line in _colorStock.text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.lastIndexOf(':');
      if (separator <= 0) {
        _showColorStockError();
        return;
      }
      final color = trimmed.substring(0, separator).trim();
      final quantity = int.tryParse(trimmed.substring(separator + 1).trim());
      if (color.isEmpty ||
          color.length > 80 ||
          quantity == null ||
          quantity < 0 ||
          colorStock.containsKey(color)) {
        _showColorStockError();
        return;
      }
      colorStock[color] = quantity;
    }
    final totalColorStock = colorStock.values.fold<int>(0, (a, b) => a + b);
    final totalStock = int.tryParse(_stock.text);
    if (totalStock == null || totalColorStock > totalStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le stock des couleurs dépasse le stock du produit.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await adminApiService.saveProduct(widget.product, {
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'category': _category.text.trim(),
        'description': _description.text.trim(),
        'price': double.parse(_price.text),
        'promo_price': _promo.text.trim().isEmpty
            ? ''
            : double.parse(_promo.text),
        'stock': int.parse(_stock.text),
        'color_stock': colorStock,
        'icon': 'devices',
        'image_urls': [
          ..._imageUrls,
          if (_imageUrl.text.trim().isNotEmpty) _imageUrl.text.trim(),
        ],
        'specs': specs,
      }, images: _images);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;

  void _showColorStockError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saisis une couleur par ligne au format « Noir: 5 ».'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoCount =
        _imageUrls.length +
        _images.length +
        (_imageUrl.text.trim().isEmpty ? 0 : 1);
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Ajouter un article' : 'Modifier l’article',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Nom'),
                _field(_brand, 'Marque'),
                _field(_category, 'Catégorie'),
                _field(_description, 'Description', maxLines: 3),
                _field(_price, 'Prix', keyboardType: TextInputType.number),
                _field(
                  _promo,
                  'Prix promotionnel (facultatif)',
                  keyboardType: TextInputType.number,
                  required: false,
                ),
                _field(_stock, 'Stock', keyboardType: TextInputType.number),
                _field(
                  _colorStock,
                  'Couleurs et stock',
                  maxLines: 4,
                  required: false,
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Une couleur par ligne, par exemple « Noir: 5 » ou « Blanc: 0 » pour indisponible. Le total ne doit pas dépasser le stock du produit.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Photos ($photoCount/5)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_imageUrls.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final imageUrl in _imageUrls)
                        _existingImage(imageUrl),
                    ],
                  ),
                for (final image in _images)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(image.name, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Retirer la photo',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _images.remove(image)),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                if (photoCount < 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Ajouter des photos'),
                    ),
                  ),
                _field(
                  _imageUrl,
                  'Ajouter une URL de photo (facultatif)',
                  required: false,
                  onChanged: (_) => setState(() {}),
                ),
                if (photoCount >= 5)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Maximum 5 photos par article.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                _field(_specs, 'Caractéristiques au format JSON', maxLines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _existingImage(String imageUrl) => SizedBox(
    width: 72,
    height: 72,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            apiClient.resolveImageUrl(imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filledTonal(
            tooltip: 'Retirer la photo',
            visualDensity: VisualDensity.compact,
            onPressed: _saving
                ? null
                : () => setState(() => _imageUrls.remove(imageUrl)),
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && _required(value) != null) return 'Champ obligatoire';
        if (keyboardType == TextInputType.number &&
            value != null &&
            value.isNotEmpty &&
            num.tryParse(value) == null) {
          return 'Valeur numérique invalide';
        }
        return null;
      },
    ),
  );
}
