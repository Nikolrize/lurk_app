import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/verification_provider.dart';

class PrivateVerificationPhoto extends ConsumerStatefulWidget {
  const PrivateVerificationPhoto({
    super.key,
    required this.viewerUid,
    required this.path,
  });
  final String viewerUid;
  final String path;
  @override
  ConsumerState<PrivateVerificationPhoto> createState() =>
      _PrivateVerificationPhotoState();
}

class _PrivateVerificationPhotoState
    extends ConsumerState<PrivateVerificationPhoto> {
  late Future<Uint8List> _photo;
  @override
  void initState() {
    super.initState();
    _photo = _download();
  }

  @override
  void didUpdateWidget(covariant PrivateVerificationPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerUid != widget.viewerUid ||
        oldWidget.path != widget.path) {
      _photo = _download();
    }
  }

  Future<Uint8List> _download() => ref
      .read(verificationStorageServiceProvider)
      .downloadIdPhoto(expectedViewerUid: widget.viewerUid, path: widget.path);
  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(authStateProvider).asData?.value;
    if (viewer?.uid != widget.viewerUid) return const SizedBox.shrink();
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: FutureBuilder<Uint8List>(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load the private ID photo.'),
                  TextButton(
                    onPressed: () => setState(() => _photo = _download()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                semanticLabel: 'Private identification photo',
                errorBuilder: (_, error, stackTrace) => const Center(
                  child: Text('This image cannot be displayed.'),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
