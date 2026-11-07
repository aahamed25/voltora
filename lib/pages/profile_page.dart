import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../pages/admin_dashboard_page.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import 'login_page.dart';
import 'register_page.dart';

const _lightViolet = Color(0xFFE9E4FF);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _handleAccountAction(BuildContext context, String action) async {
    try {
      await authService.logout();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
    appState.clearUserData();
    if (action == 'switch' && context.mounted) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
    }
  }

  Widget _informationRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: kViolet, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Non renseigné' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 536
            ? 500.0
            : constraints.maxWidth - 36;
        final minHeight = constraints.maxHeight > 48
            ? constraints.maxHeight - 48
            : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: SizedBox(
                width: cardWidth,
                child: ListenableBuilder(
                  listenable: authService,
                  builder: (context, _) {
                    final user = authService.currentUser;
                    return Card(
                      color: Colors.white,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                const Text(
                                  'Voltora',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: kViolet,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (user != null)
                                  PopupMenuButton<String>(
                                    tooltip: 'Options du compte',
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: kViolet,
                                    ),
                                    onSelected: (action) =>
                                        _handleAccountAction(context, action),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'switch',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.switch_account),
                                          title: Text('Changer de compte'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'logout',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.logout),
                                          title: Text('Se déconnecter'),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Gestion de votre espace',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              user == null
                                  ? 'Bienvenue sur Voltora. Connectez-vous ou créez un compte pour accéder à votre espace.'
                                  : 'Bienvenue ${user.prenom} ${user.nom} dans votre espace.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF3F4652),
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            if (user != null) ...[
                              if (user.isAdmin) ...[
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const AdminDashboardPage(),
                                      ),
                                    ),
                                    icon: const Icon(Icons.dashboard_outlined),
                                    label: const Text('Ouvrir le tableau de bord'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const Divider(),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Mes informations',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _informationRow(
                                Icons.person_outline,
                                'Nom complet',
                                '${user.prenom} ${user.nom}',
                              ),
                              _informationRow(
                                Icons.alternate_email,
                                'Identifiant',
                                user.username,
                              ),
                              _informationRow(
                                Icons.email_outlined,
                                'E-mail',
                                user.email,
                              ),
                              _informationRow(
                                Icons.phone_outlined,
                                'Téléphone',
                                user.phone,
                              ),
                              _informationRow(
                                Icons.cake_outlined,
                                'Date de naissance',
                                '${user.birthDate.day.toString().padLeft(2, '0')}/'
                                    '${user.birthDate.month.toString().padLeft(2, '0')}/'
                                    '${user.birthDate.year}',
                              ),
                              _informationRow(
                                Icons.verified_user_outlined,
                                'Type de compte',
                                user.isAdmin ? 'Administrateur' : 'Client',
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (user == null) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const LoginPage(),
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kViolet,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  child: const Text(
                                    'Se connecter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _lightViolet,
                                    foregroundColor: kViolet,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  child: const Text(
                                    'Créer un compte',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!authService.hasAdmin) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegisterPage(
                                      isAdminCreation: true,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.admin_panel_settings),
                                label: const Text(
                                  'Créer le compte administrateur',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
