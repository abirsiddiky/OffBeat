import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/playlist_model.dart';
import '../../data/repository/music_repository.dart';

class PlaylistDialogs {
  PlaylistDialogs._();

  static Future<void> showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(musicRepositoryProvider).createPlaylist(name);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) async {
    final controller = TextEditingController(text: playlist.name);
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'New playlist name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref.read(musicRepositoryProvider).renamePlaylist(playlist.id, name);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    PlaylistModel playlist,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Playlist'),
          content: Text('Are you sure you want to delete "${playlist.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await ref.read(musicRepositoryProvider).deletePlaylist(playlist.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
