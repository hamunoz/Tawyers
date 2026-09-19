/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/models/plugin_model.dart';
import 'package:musify/services/plugin_manager.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  final TextEditingController _repoController = TextEditingController(
    text: 'https://raw.githubusercontent.com/musify/plugins/main/repository.json',
  );

  @override
  void initState() {
    super.initState();
    pluginManager.init();
  }

  @override
  void dispose() {
    _repoController.dispose();
    super.dispose();
  }

  void _showEditIptvUrlDialog(BuildContext context, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('URL de Lista M3U Personalizada'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://ejemplo.com/playlist.m3u',
              labelText: 'URL M3U / M3U8',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n!.cancel),
            ),
            FilledButton(
              onPressed: () async {
                await pluginManager.setCustomIptvUrl(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL M3U guardada con éxito')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n!.pluginManager),
      ),
      body: Material(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n!.installedPlugins,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<PluginModel>>(
                valueListenable: pluginManager.pluginsNotifier,
                builder: (context, plugins, _) {
                  if (plugins.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Cargando plugins preinstalados...'),
                    );
                  }

                  return Column(
                    children: plugins.map((plugin) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: plugin.enabled,
                              onChanged: (val) {
                                pluginManager.togglePlugin(plugin.id, val);
                              },
                              title: Text(
                                '${plugin.name} (v${plugin.version})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(plugin.description),
                              ),
                              secondary: Icon(
                                _getPluginIcon(plugin.type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (plugin.id == 'iptv_audio') ...[
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              FutureBuilder<String>(
                                future: pluginManager.getCustomIptvUrl(),
                                builder: (context, snapshot) {
                                  final currentUrl = snapshot.data ?? '';
                                  return ListTile(
                                    leading: const Icon(Icons.link),
                                    title: const Text('URL de Lista M3U / M3U8'),
                                    subtitle: Text(
                                      currentUrl.isNotEmpty
                                          ? currentUrl
                                          : 'Por defecto: iptv-org.github.io/iptv/index.m3u',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => _showEditIptvUrlDialog(context, currentUrl),
                                      child: const Text('Editar URL'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              /*
              const Divider(height: 32),
              Text(
                'Repositorio de Plugins Remotos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Configuración para actualizar y descargar plugins remotamente en futuras versiones.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repoController,
                decoration: const InputDecoration(
                  labelText: 'URL del Repositorio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sincronización remota preparada para V2'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar Repositorio (Proximamente V2)'),
                ),
              ),
              */
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPluginIcon(String type) {
    switch (type) {
      case 'radio':
        return Icons.radio;
      case 'iptv_audio':
        return Icons.live_tv;
      case 'music':
        return Icons.music_note;
      default:
        return Icons.extension;
    }
  }
}
