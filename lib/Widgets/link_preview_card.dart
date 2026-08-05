import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connect/Config/app_theme.dart';

class LinkPreviewCard extends StatelessWidget {
  final String url;
  final VoidCallback? onRemove;
  final bool isCompact;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.onRemove,
    this.isCompact = false,
  });

  Future<void> _launchUrl(String targetUrl) async {
    final Uri uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.surfaceSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.accentPrimary.withValues(alpha: 0.25),
              width: 1.0,
            ),
          ),
          child: AnyLinkPreview(
            link: url,
            displayDirection: UIDirection.uiDirectionHorizontal,
            errorWidget: _buildFallbackPreview(context, url),
            placeholderWidget: Container(
              height: 70,
              padding: const EdgeInsets.all(12),
              color: context.surfaceSecondary,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Loading preview...",
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            cache: const Duration(hours: 24),
            titleStyle: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            bodyStyle: TextStyle(
              color: context.textSecondary,
              fontSize: 11,
            ),
            backgroundColor: context.surfaceSecondary,
            borderRadius: 14,
            onTap: () => _launchUrl(url),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(5.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackPreview(BuildContext context, String rawUrl) {
    final Uri? uri = Uri.tryParse(rawUrl);
    final String host = uri?.host ?? rawUrl;

    return InkWell(
      onTap: () => _launchUrl(rawUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: context.surfaceSecondary,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_rounded,
                size: 18,
                color: context.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    host,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rawUrl,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
