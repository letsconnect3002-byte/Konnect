import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/ThreadDetailPage.dart';
import 'package:connect/Models/feed_post.dart';
// import 'package:connect/Pages/YourNetworkPage.dart';
import 'package:connect/Widgets/connect_hub_bottom_sheet.dart';
import 'package:connect/Widgets/post_card.dart';
import 'package:connect/Widgets/dwell_detector.dart';
import 'package:connect/Widgets/threaded_comment_tree.dart';
import 'package:connect/Widgets/link_preview_card.dart';
import 'package:connect/Widgets/pulse_row_widget.dart';
import 'package:connect/Providers/pulse_provider.dart';
import 'package:connect/Providers/notification_provider.dart';
import 'package:connect/Pages/NotificationPage.dart';
import 'package:connect/services/analytics_service.dart';

class CircleFeedPage extends StatefulWidget {
  const CircleFeedPage({super.key});

  @override
  State<CircleFeedPage> createState() => _CircleFeedPageState();

  static void openComposeSheet(BuildContext context,
      {String? initialText, String? initialUrl}) {
    HapticFeedback.lightImpact();
    final connectionProvider =
        Provider.of<ConnectionProvider>(context, listen: false);
    final connections = connectionProvider.connections;
    final connectionNames = connections
        .map((c) => (c['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);

    // 1. Extract initial attached URL from initialUrl or initialText
    String? attachedUrl = (initialUrl != null && initialUrl.trim().isNotEmpty)
        ? initialUrl.trim()
        : null;

    final rawInitialText = initialText ?? '';
    if (attachedUrl == null || attachedUrl.isEmpty) {
      final match = urlRegex.firstMatch(rawInitialText);
      if (match != null) {
        attachedUrl = match.group(0);
      }
    }

    // 2. Completely strip all URLs from rawInitialText for user text input box
    String initialUserText = rawInitialText.replaceAll(urlRegex, '').trim();
    if (attachedUrl != null && attachedUrl.isNotEmpty) {
      initialUserText = initialUserText.replaceAll(attachedUrl, '').trim();
    }

    final controller = _MentionTextEditingController(
      accentColor: context.accentPrimary,
      connectionNames: connectionNames,
    );
    controller.text = initialUserText;
    controller.selection =
        TextSelection.collapsed(offset: initialUserText.length);

    bool isSubmitting = false;
    bool isPreviewDetached = false;
    String postVisibility = 'both'; // 'both', 'casual', 'professional'
    final feedProviderRef = Provider.of<FeedProvider>(context, listen: false);
    final bool isGlobalFeed = feedProviderRef.feedFilter == FeedFilter.global;
    bool isAnonymousPost = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final connectionProvider =
              Provider.of<ConnectionProvider>(context, listen: false);
          final connections = connectionProvider.connections;
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

          final trimmedText = controller.text.trim();
          final charCount = controller.text.length;

          final String? activeUrl = isPreviewDetached ? null : attachedUrl;
          final bool isValid = (trimmedText.isNotEmpty ||
                  (activeUrl != null && activeUrl.isNotEmpty)) &&
              charCount <= 500 &&
              !isSubmitting;

          // Mention detection
          final text = controller.text;
          final cursorPos = controller.selection.baseOffset;
          String mentionQuery = '';
          int atIndex = -1;
          List<Map<String, dynamic>> mentionSuggestions = [];

          if (cursorPos > 0 && cursorPos <= text.length) {
            final textBeforeCursor = text.substring(0, cursorPos);
            atIndex = textBeforeCursor.lastIndexOf('@');
            if (atIndex != -1) {
              if (atIndex == 0 ||
                  RegExp(r'\s').hasMatch(textBeforeCursor[atIndex - 1])) {
                mentionQuery = textBeforeCursor.substring(atIndex + 1);
                if (!mentionQuery.contains('\n')) {
                  final q = mentionQuery.toLowerCase();
                  mentionSuggestions = connections
                      .where((c) {
                        final name = (c['name'] ?? '').toString().toLowerCase();
                        return name.contains(q);
                      })
                      .take(5)
                      .toList();
                }
              }
            }
          }

          void insertMention(Map<String, dynamic> conn) {
            HapticFeedback.lightImpact();
            final name = conn['name']?.toString() ?? 'User';
            final String replacement = "@$name ";
            final String currentText = controller.text;
            final String newText =
                currentText.replaceRange(atIndex, cursorPos, replacement);
            controller.text = newText;
            final newCursorPos = atIndex + replacement.length;
            controller.selection =
                TextSelection.collapsed(offset: newCursorPos);
            setSheetState(() {});
          }

          Widget buildAudienceTab(String value, String title, IconData icon) {
            final isSelected = postVisibility == value;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setSheetState(() => postVisibility = value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected ? context.accentSecondary : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: context.accentSecondary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 13,
                        color: isSelected ? Colors.white : context.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : context.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + bottomPadding,
              ),
              decoration: BoxDecoration(
                color: context.surfacePrimary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        "New Post",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "$charCount / 500",
                        style: TextStyle(
                          color: charCount > 500
                              ? Colors.redAccent
                              : context.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (isGlobalFeed) ...[
                    // Global Feed Anonymity Selector
                    Container(
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAnonymousPost
                              ? context.accentPrimary.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isAnonymousPost
                                  ? context.accentPrimary.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                            child: Icon(
                              isAnonymousPost
                                  ? Icons.visibility_off_rounded
                                  : Icons.person_rounded,
                              size: 18,
                              color: isAnonymousPost
                                  ? context.accentSecondary
                                  : context.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Post Anonymously",
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Builder(
                                  builder: (context) {
                                    final profileProvider =
                                        Provider.of<ProfileProvider>(context,
                                            listen: false);
                                    final anonAlias = profileProvider.anonName.isNotEmpty
                                        ? profileProvider.anonName
                                        : "Anonymous";
                                    return Text(
                                      isAnonymousPost
                                          ? "Appearing as $anonAlias"
                                          : "Appearing as ${profileProvider.name}",
                                      style: TextStyle(
                                        color: isAnonymousPost
                                            ? context.accentSecondary
                                            : context.textMuted,
                                        fontSize: 11,
                                        fontWeight: isAnonymousPost
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: isAnonymousPost,
                            activeThumbColor: context.accentPrimary,
                            activeTrackColor: context.accentPrimary.withValues(alpha: 0.5),
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setSheetState(() => isAnonymousPost = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Text(
                      postVisibility == 'both'
                          ? "Visible to all connections across your network."
                          : postVisibility == 'professional'
                              ? "Visible only to your professional network."
                              : "Visible only to your casual / personal network.",
                      style:
                          TextStyle(color: context.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    // Audience Selector Segment
                    Container(
                      decoration: BoxDecoration(
                        color: context.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          buildAudienceTab('both', 'All Circles', Icons.public_rounded),
                          buildAudienceTab('casual', 'Casual', Icons.coffee_rounded),
                          buildAudienceTab('professional', 'Professional', Icons.work_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: controller,
                    maxLines: 4,
                    autofocus: true,
                    onChanged: (val) {
                      final matches = urlRegex.allMatches(val).toList();
                      if (matches.isNotEmpty) {
                        if (attachedUrl == null && !isPreviewDetached) {
                          attachedUrl = matches.first.group(0);
                        }
                        final textWithoutUrls =
                            val.replaceAll(urlRegex, '').trim();
                        controller.value = TextEditingValue(
                          text: textWithoutUrls,
                          selection: TextSelection.collapsed(
                              offset: textWithoutUrls.length),
                        );
                      }
                      setSheetState(() {});
                    },
                    style: TextStyle(color: context.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "What's on your mind? Use @ to mention someone",
                      hintStyle:
                          TextStyle(color: context.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: context.surfaceSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                    ),
                  ),
                  if (activeUrl != null && activeUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LinkPreviewCard(
                      url: activeUrl,
                      onRemove: () {
                        setSheetState(() {
                          isPreviewDetached = true;
                          attachedUrl = null;
                          final textWithoutUrls =
                              controller.text.replaceAll(urlRegex, '').trim();
                          controller.value = TextEditingValue(
                            text: textWithoutUrls,
                            selection: TextSelection.collapsed(
                                offset: textWithoutUrls.length),
                          );
                        });
                      },
                    ),
                  ],
                  if (mentionSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: Material(
                        color: context.surfaceSecondary,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color:
                                  context.accentPrimary.withValues(alpha: 0.4)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: mentionSuggestions.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06)),
                          itemBuilder: (context, idx) {
                            final conn = mentionSuggestions[idx];
                            final name = conn['name']?.toString() ?? 'User';
                            final avatarUrl = conn['avatarUrl']?.toString() ??
                                conn['avatar_url']?.toString() ??
                                '';
                            final profession =
                                conn['profession']?.toString() ?? '';

                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: context.accentPrimary,
                                backgroundImage: avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl.isEmpty
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.white))
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: profession.isNotEmpty
                                  ? Text(
                                      profession,
                                      style: TextStyle(
                                          color: context.textMuted,
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => insertMention(conn),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final pos = controller.selection.baseOffset;
                          final currentText = controller.text;
                          final insertPos =
                              (pos >= 0 && pos <= currentText.length)
                                  ? pos
                                  : currentText.length;
                          final newText = currentText.replaceRange(
                              insertPos, insertPos, "@");
                          controller.text = newText;
                          controller.selection =
                              TextSelection.collapsed(offset: insertPos + 1);
                          setSheetState(() {});
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                context.accentPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: context.accentPrimary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alternate_email_rounded,
                                  size: 14, color: context.accentPrimary),
                              const SizedBox(width: 4),
                              Text(
                                "Mention",
                                style: TextStyle(
                                  color: context.accentPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: isValid
                          ? () async {
                              setSheetState(() => isSubmitting = true);
                              final profileProvider =
                                  Provider.of<ProfileProvider>(context,
                                      listen: false);
                              final feedProvider = Provider.of<FeedProvider>(
                                  context,
                                  listen: false);

                              String postContent = trimmedText;
                              if (activeUrl != null && activeUrl.isNotEmpty) {
                                postContent = postContent.isNotEmpty
                                    ? "$postContent\n$activeUrl"
                                    : activeUrl;
                              }

                              try {
                                await feedProvider.createPost(
                                  postContent,
                                  authorName: isAnonymousPost
                                      ? (profileProvider.anonName.isNotEmpty
                                          ? profileProvider.anonName
                                          : 'Anonymous')
                                      : profileProvider.name,
                                  authorAvatarUrl: isAnonymousPost
                                      ? ''
                                      : profileProvider.avatarUrl,
                                  connections: connections,
                                  visibility: postVisibility,
                                  isAnonymous: isAnonymousPost,
                                );
                                AnalyticsService.logEvent(
                                  name: 'post_created',
                                  parameters: {
                                    'visibility': postVisibility,
                                    'char_count': postContent.length,
                                    'has_link': (activeUrl != null && activeUrl.isNotEmpty) ? 1 : 0,
                                    'mentions_count': RegExp(r'@[a-zA-Z0-9_]+').allMatches(postContent).length,
                                    'is_anonymous': isAnonymousPost ? 1 : 0,
                                  },
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isAnonymousPost
                                  ? "Post Anonymously"
                                  : (isGlobalFeed
                                      ? "Post to Global"
                                      : "Post to Network"),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CircleFeedPageState extends State<CircleFeedPage> {
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _feedChannel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final connectionProvider =
          Provider.of<ConnectionProvider>(context, listen: false);
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      if (feedProvider.viewerId != profileProvider.userId) {
        feedProvider.updateFromProviders(
          profileProvider.userId,
          connectionProvider.connections.length,
          isConnectionsLoaded:
              connectionProvider.state is UserConnectionLoaded ||
                  connectionProvider.state is UserConnectionError,
        );
      }
      _subscribeToFeedRealtime();
    });
  }

  void _subscribeToFeedRealtime() {
    final client = Supabase.instance.client;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final userId = profileProvider.userId ?? 0;

    if (_feedChannel != null) {
      client.removeChannel(_feedChannel!);
      _feedChannel = null;
    }

    _feedChannel = client.channel('feed:viewer_$userId');
    _feedChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'post_reactions',
        callback: (payload) {
          debugPrint(
              '[REALTIME_SIGNAL: CIRCLE_FEED] post_reactions INSERT received: ${payload.newRecord}');
          final feedProvider =
              Provider.of<FeedProvider>(context, listen: false);
          feedProvider.handleReactionRealtimePayload(
            eventType: 'INSERT',
            newRecord: Map<String, dynamic>.from(payload.newRecord),
            oldRecord: Map<String, dynamic>.from(payload.oldRecord),
          );
          if (mounted) setState(() {});
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'post_reactions',
        callback: (payload) {
          debugPrint(
              '[REALTIME_SIGNAL: CIRCLE_FEED] post_reactions UPDATE received: ${payload.newRecord}');
          final feedProvider =
              Provider.of<FeedProvider>(context, listen: false);
          feedProvider.handleReactionRealtimePayload(
            eventType: 'UPDATE',
            newRecord: Map<String, dynamic>.from(payload.newRecord),
            oldRecord: Map<String, dynamic>.from(payload.oldRecord),
          );
          if (mounted) setState(() {});
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'post_reactions',
        callback: (payload) {
          debugPrint(
              '[REALTIME_SIGNAL: CIRCLE_FEED] post_reactions DELETE received: ${payload.oldRecord}');
          final feedProvider =
              Provider.of<FeedProvider>(context, listen: false);
          feedProvider.handleReactionRealtimePayload(
            eventType: 'DELETE',
            newRecord: Map<String, dynamic>.from(payload.newRecord),
            oldRecord: Map<String, dynamic>.from(payload.oldRecord),
          );
          if (mounted) setState(() {});
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'posts',
        callback: (payload) {
          debugPrint(
              '[REALTIME_SIGNAL: CIRCLE_FEED] posts UPDATE received: ${payload.newRecord['id']} -> ${payload.newRecord['reaction_counts']}');
          final feedProvider =
              Provider.of<FeedProvider>(context, listen: false);
          feedProvider.handlePostRealtimePayload(
              Map<String, dynamic>.from(payload.newRecord));
          if (mounted) setState(() {});
        },
      )
      .subscribe((status, error) {
        debugPrint(
            '[REALTIME_SIGNAL: CIRCLE_FEED] Channel status: $status, error: $error');
      });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (_feedChannel != null) {
      Supabase.instance.client.removeChannel(_feedChannel!);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.fetchNextPage();
    }
  }

  void _openComposeSheet(BuildContext context) {
    CircleFeedPage.openComposeSheet(context);
  }

  Widget _buildCaughtUpDivider(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: context.accentPrimary),
                const SizedBox(width: 6),
                Text(
                  "You're all caught up",
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  void _openFeedFilterSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: context.surfacePrimary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            "Feed Selection",
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "Choose which circle of posts to display",
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFeedOptionCard(
                        title: "Global Feed",
                        description:
                            "All posts across the platform without any network filters",
                        icon: Icons.language_rounded,
                        isSelected: feedProvider.feedFilter == FeedFilter.global,
                        onTap: () {
                          if (feedProvider.feedFilter != FeedFilter.global) {
                            HapticFeedback.selectionClick();
                            feedProvider.setFilter(FeedFilter.global);
                            setSheetState(() {});
                            AnalyticsService.logEvent(
                              name: 'feed_filter_changed',
                              parameters: {'filter': 'global'},
                            );
                          }
                          Navigator.pop(sheetContext);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFeedOptionCard(
                        title: "Full Network",
                        description:
                            "Posts from direct connections and extended network",
                        icon: Icons.public_rounded,
                        isSelected:
                            feedProvider.feedFilter == FeedFilter.fullNetwork,
                        onTap: () {
                          if (feedProvider.feedFilter !=
                              FeedFilter.fullNetwork) {
                            HapticFeedback.selectionClick();
                            feedProvider.setFilter(FeedFilter.fullNetwork);
                            setSheetState(() {});
                            AnalyticsService.logEvent(
                              name: 'feed_filter_changed',
                              parameters: {'filter': 'full_network'},
                            );
                          }
                          Navigator.pop(sheetContext);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFeedOptionCard(
                        title: "Inner Circle",
                        description:
                            "Posts exclusively from your direct 1st-degree connections",
                        icon: Icons.people_alt_rounded,
                        isSelected:
                            feedProvider.feedFilter == FeedFilter.innerCircle,
                        onTap: () {
                          if (feedProvider.feedFilter !=
                              FeedFilter.innerCircle) {
                            HapticFeedback.selectionClick();
                            feedProvider.setFilter(FeedFilter.innerCircle);
                            setSheetState(() {});
                            AnalyticsService.logEvent(
                              name: 'feed_filter_changed',
                              parameters: {'filter': 'inner_circle'},
                            );
                          }
                          Navigator.pop(sheetContext);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeedOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return BounceTap(
      onTap: onTap,
      scaleDown: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentPrimary.withValues(alpha: 0.12)
              : context.surfaceSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.accentPrimary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.accentPrimary.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.accentPrimary.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? context.accentPrimary
                    : context.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12.5,
                      height: 1.3,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? context.accentPrimary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? context.accentPrimary
                      : context.textSecondary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty1DegreeState(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const PulseRowWidget(),
          Container(
            height: MediaQuery.of(context).size.height * 0.52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.accentPrimary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 32,
                    color: context.accentPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "No Inner Circle Posts",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "None of your direct 1st-degree connections have posted yet. Switch to Full Network to see posts from your extended network.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    feedProvider.setFilter(FeedFilter.fullNetwork);
                  },
                  icon: const Icon(Icons.public_rounded,
                      color: Colors.white, size: 18),
                  label: const Text(
                    "View Full Network",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);
    final List<FeedPost> displayedPosts = feedProvider.displayedPosts;

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 56,
            color: context.canvasBackground,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Left: Jana + Unseen Badge
                Positioned(
                  left: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Jana",
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (feedProvider.unseenCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.accentPrimary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            "${feedProvider.unseenCount} new",
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Center: Perfectly centered filter button
                Center(
                  child: BounceTap(
                    onTap: () => _openFeedFilterSheet(context),
                    scaleDown: 0.94,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: context.surfacePrimary,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            feedProvider.feedFilter == FeedFilter.global
                                ? Icons.language_rounded
                                : (feedProvider.feedFilter ==
                                        FeedFilter.innerCircle
                                    ? Icons.people_alt_rounded
                                    : Icons.public_rounded),
                            size: 14,
                            color: context.accentPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            feedProvider.feedFilter == FeedFilter.global
                                ? "Global Feed"
                                : (feedProvider.feedFilter ==
                                        FeedFilter.innerCircle
                                    ? "Inner Circle"
                                    : "Full Network"),
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: context.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right: Notification Icon Button
                Positioned(
                  right: 16,
                  child: Consumer<NotificationProvider>(
                    builder: (context, notifProvider, child) {
                      final unread = notifProvider.unreadCount;
                      return Center(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationPage(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.surfacePrimary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.04)),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: -1,
                                    top: -1,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: context.surfacePrimary,
                                            width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFEF4444)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 8,
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: feedProvider.isLoading && feedProvider.posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        AnalyticsService.logEvent(
                          name: 'feed_refresh_triggered',
                          parameters: {'trigger': 'pull_to_refresh'},
                        );
                        final pulseProvider =
                            Provider.of<PulseProvider>(context, listen: false);
                        await Future.wait([
                          feedProvider.fetchInitialFeed(),
                          pulseProvider.loadFeed(),
                          pulseProvider.loadMyPulse(),
                        ]);
                      },
                      backgroundColor: context.surfacePrimary,
                      color: context.accentPrimary,
                      child: feedProvider.posts.isEmpty
                          ? Builder(
                              builder: (context) {
                                final connectionProvider =
                                    Provider.of<ConnectionProvider>(context);
                                final bool hasNoConnections =
                                    connectionProvider.connections.isEmpty;

                                return SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: Column(
                                    children: [
                                      const PulseRowWidget(),
                                      Container(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.55,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                color: context.accentPrimary
                                                    .withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: context.accentPrimary
                                                      .withValues(alpha: 0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Icon(
                                                feedProvider.feedFilter ==
                                                        FeedFilter.global
                                                    ? Icons.language_rounded
                                                    : (hasNoConnections
                                                        ? Icons
                                                            .people_outline_rounded
                                                        : Icons
                                                            .dynamic_feed_rounded),
                                                size: 32,
                                                color: context.accentPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              feedProvider.feedFilter ==
                                                      FeedFilter.global
                                                  ? "No Global Posts Yet"
                                                  : (hasNoConnections
                                                      ? "Build Your Network"
                                                      : "No Posts Yet"),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              feedProvider.feedFilter ==
                                                      FeedFilter.global
                                                  ? "There are no posts shared in the global feed yet. Be the first to post!"
                                                  : (hasNoConnections
                                                      ? "Connect with friends and colleagues to start seeing posts and pulses in your feed."
                                                      : "No post shared by your network yet, be first to do so."),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: context.textSecondary,
                                                fontSize: 13.5,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 22),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                if (feedProvider.feedFilter ==
                                                    FeedFilter.global) {
                                                  _openComposeSheet(context);
                                                } else if (hasNoConnections) {
                                                  showModalBottomSheet(
                                                    context: context,
                                                    isScrollControlled: true,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    builder: (context) =>
                                                        const ConnectHubBottomSheet(
                                                      initialTabIndex: 1,
                                                      showOnboardingSteps: true,
                                                    ),
                                                  );
                                                } else {
                                                  _openComposeSheet(context);
                                                }
                                              },
                                              icon: Icon(
                                                (feedProvider.feedFilter !=
                                                            FeedFilter
                                                                .global &&
                                                        hasNoConnections)
                                                    ? Icons.person_add_rounded
                                                    : Icons.add_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              label: Text(
                                                (feedProvider.feedFilter !=
                                                            FeedFilter
                                                                .global &&
                                                        hasNoConnections)
                                                    ? "Connect with People"
                                                    : "Share First Post",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    context.accentPrimary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : displayedPosts.isEmpty
                              ? _buildEmpty1DegreeState(context)
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: displayedPosts.length + 2,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return const PulseRowWidget();
                                    }

                                    if (index == displayedPosts.length + 1) {
                                      if (feedProvider.isLoadingMore) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 20),
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        );
                                      }
                                      return const SizedBox(height: 80);
                                    }

                                    final post = displayedPosts[index - 1];
                                    final postIndex = index - 1;

                                    final bool showDividerHere = feedProvider
                                            .hasShownCaughtUpDivider &&
                                        postIndex > 0 &&
                                        displayedPosts[postIndex - 1].degree ==
                                            post.degree;
                                    return Column(
                                      children: [
                                        if (showDividerHere && postIndex == 5)
                                          _buildCaughtUpDivider(context),
                                        DwellDetector(
                                          onDwell: () {
                                            feedProvider
                                                .markPostSeenLocally(post.id);
                                            AnalyticsService.logEvent(
                                              name: 'feed_post_dwelled',
                                              parameters: {
                                                'post_id': post.id,
                                                'author_degree': post.degree,
                                              },
                                            );
                                          },
                                          child: _FeedPostThreadItem(
                                            key: ValueKey(
                                                "feed_item_${post.id}"),
                                            post: post,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ThreadDetailPage(
                                                          rootPostId: post.id),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                    ),
                    if (feedProvider.hasNewPosts)
                      Positioned(
                        top: 14,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                AnalyticsService.logEvent(
                                  name: 'feed_refresh_triggered',
                                  parameters: {'trigger': 'banner_click'},
                                );
                                feedProvider.loadNewPosts();
                                if (_scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(99),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                decoration: BoxDecoration(
                                  color: context.accentPrimary,
                                  borderRadius: BorderRadius.circular(99),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.accentPrimary
                                          .withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "New post",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: 'network_feed_fab',
          backgroundColor: context.accentPrimary,
          elevation: 4,
          onPressed: () => _openComposeSheet(context),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _MentionTextEditingController extends TextEditingController {
  final Color accentColor;
  final List<String> connectionNames;

  _MentionTextEditingController({
    required this.accentColor,
    required this.connectionNames,
    String? text,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textVal = text;
    if (textVal.isEmpty) {
      return TextSpan(style: style);
    }

    final sortedNames = List<String>.from(connectionNames)
      ..sort((a, b) => b.length.compareTo(a.length));
    final escapedNames = sortedNames.map((n) => RegExp.escape(n)).join('|');

    final String pattern = escapedNames.isNotEmpty
        ? r'@(' + escapedNames + r'|[A-Za-z0-9_\-\.]+)'
        : r'@[A-Za-z0-9_\-\.]+';

    final RegExp mentionRegex = RegExp(pattern, caseSensitive: false);
    final matches = mentionRegex.allMatches(textVal);

    final List<InlineSpan> children = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: textVal.substring(lastIndex, match.start),
          style: style,
        ));
      }

      children.add(TextSpan(
        text: match.group(0),
        style: style?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ) ??
            TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < textVal.length) {
      children.add(TextSpan(
        text: textVal.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

class _FeedPostThreadItem extends StatefulWidget {
  final FeedPost post;
  final VoidCallback onTap;

  const _FeedPostThreadItem({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  State<_FeedPostThreadItem> createState() => _FeedPostThreadItemState();
}

class _FeedPostThreadItemState extends State<_FeedPostThreadItem> {
  CommentNode? _treeNode;
  bool _isLoadingThread = false;
  String? _lastFetchedPostId;
  StreamSubscription<Map<String, dynamic>>? _postUpdateSub;

  @override
  void initState() {
    super.initState();
    if (widget.post.activeReplyCount > 0) {
      _loadThreadPreview();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_postUpdateSub == null) {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      _postUpdateSub =
          feedProvider.postUpdateStream.listen(_onRealtimePostUpdate);
    }
  }

  @override
  void dispose() {
    _postUpdateSub?.cancel();
    super.dispose();
  }

  bool _isPostIdInTree(CommentNode node, String targetId) {
    if (node.id == targetId) return true;
    for (final child in node.replies) {
      if (_isPostIdInTree(child, targetId)) return true;
    }
    return false;
  }

  void _onRealtimePostUpdate(Map<String, dynamic> payload) {
    if (!mounted) return;

    final String table = payload['table']?.toString() ?? 'posts';
    final String eventType = payload['eventType']?.toString() ?? '';
    final Map<String, dynamic> newRecord =
        Map<String, dynamic>.from(payload['new'] ?? {});
    final Map<String, dynamic> oldRecord =
        Map<String, dynamic>.from(payload['old'] ?? {});

    if (table == 'post_reactions') {
      final String targetPostId = newRecord['post_id']?.toString() ??
          oldRecord['post_id']?.toString() ??
          '';
      if (targetPostId.isEmpty) return;

      debugPrint(
          '[REALTIME_SIGNAL: UI] _onRealtimePostUpdate post_reactions $eventType for targetPostId: $targetPostId (itemRootId: ${widget.post.id})');

      if (_treeNode != null && _isPostIdInTree(_treeNode!, targetPostId)) {
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        final currentViewerId = feedProvider.viewerId;

        CommentNode applyReactionUpdate(CommentNode node) {
          if (node.id == targetPostId && node.post != null) {
            final updatedPost = applyReactionDelta(
              node.post!,
              eventType: eventType,
              newRecord: newRecord,
              oldRecord: oldRecord,
              viewerId: currentViewerId,
            );
            debugPrint(
                '[REALTIME_SIGNAL: UI] Updated tree node post $targetPostId reactions to: ${updatedPost.reactionCounts}');
            return node.copyWith(
              post: updatedPost,
              replies: node.replies.map(applyReactionUpdate).toList(),
            );
          }
          return node.copyWith(
            replies: node.replies.map(applyReactionUpdate).toList(),
          );
        }

        setState(() {
          _treeNode = applyReactionUpdate(_treeNode!);
        });
      } else if (targetPostId == widget.post.id) {
        debugPrint('[REALTIME_SIGNAL: UI] Calling setState on root post card ${widget.post.id}');
        setState(() {});
      }
    } else if (table == 'posts') {
      final String targetPostId = newRecord['id']?.toString() ?? '';
      final String? rootPostId = newRecord['root_post_id']?.toString();
      final String? replyToPostId = newRecord['reply_to_post_id']?.toString();

      if (eventType.toLowerCase() == 'insert' &&
          replyToPostId != null &&
          (rootPostId == widget.post.id ||
              replyToPostId == widget.post.id ||
              (_treeNode != null && _isPostIdInTree(_treeNode!, replyToPostId)))) {
        _loadThreadPreview(forceReload: true);
        return;
      }

      if (targetPostId.isNotEmpty &&
          _treeNode != null &&
          _isPostIdInTree(_treeNode!, targetPostId)) {
        if (newRecord['reaction_counts'] is Map &&
            (newRecord['reaction_counts'] as Map).isNotEmpty) {
          final Map<String, int> serverCounts = {};
          (newRecord['reaction_counts'] as Map).forEach((k, v) {
            final c = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
            if (c > 0) serverCounts[k.toString()] = c;
          });

          CommentNode applyCountsUpdate(CommentNode node) {
            if (node.id == targetPostId && node.post != null) {
              final updatedPost = node.post!.copyWith(
                reactionCounts: serverCounts,
              );
              return node.copyWith(
                post: updatedPost,
                replies: node.replies.map(applyCountsUpdate).toList(),
              );
            }
            return node.copyWith(
              replies: node.replies.map(applyCountsUpdate).toList(),
            );
          }

          setState(() {
            _treeNode = applyCountsUpdate(_treeNode!);
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant _FeedPostThreadItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.post.id != oldWidget.post.id) {
      // Post changed entirely — reset and reload
      _treeNode = null;
      _lastFetchedPostId = null;
      if (widget.post.activeReplyCount > 0) {
        _loadThreadPreview();
      }
      return;
    }

    // Same post — sync root node and all child nodes in the tree with live registry posts
    setState(() {
      if (_treeNode != null) {
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);

        CommentNode syncNodeWithLivePost(CommentNode node, {bool isRoot = false}) {
          final livePost = feedProvider.getPostById(node.id) ?? node.post;
          final int effectiveCount = isRoot
              ? (livePost != null
                  ? livePost.activeReplyCount
                  : node.replyCount)
              : node.replyCount;
          final updatedPost = livePost?.copyWith(
            replyCount: effectiveCount,
            activeReplyCount: effectiveCount,
          );
          return node.copyWith(
            post: updatedPost,
            replyCount: effectiveCount,
            replies: node.replies
                .map((child) => syncNodeWithLivePost(child, isRoot: false))
                .toList(),
          );
        }

        _treeNode = syncNodeWithLivePost(_treeNode!, isRoot: true);
      }
    });

    // If activeReplyCount went from 0 → >0 and we haven't fetched yet
    if (widget.post.activeReplyCount > 0 &&
        oldWidget.post.activeReplyCount == 0 &&
        _treeNode == null) {
      _loadThreadPreview();
    }

    // If activeReplyCount went to 0 — clear the tree
    if (widget.post.activeReplyCount == 0 && _treeNode != null) {
      setState(() {
        _treeNode = null;
      });
    }
  }

  Future<void> _loadThreadPreview({bool forceReload = false}) async {
    // Guard: don't re-fetch if we already fetched for this post
    if (_isLoadingThread ||
        (!forceReload && _lastFetchedPostId == widget.post.id)) return;
    _isLoadingThread = true;

    try {
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      final threadPosts = await feedProvider.fetchThread(widget.post.id);

      if (!mounted) return;

      _lastFetchedPostId = widget.post.id;

      if (threadPosts.isNotEmpty) {
        final rootPost = threadPosts.first;
        final replyPosts =
            threadPosts.sublist(1).where((p) => !p.isDeleted).toList();

        if (replyPosts.isNotEmpty) {
          final Map<String, List<FeedPost>> childrenMap = {};
          for (final p in replyPosts) {
            final parentId =
                (p.replyToPostId != null && p.replyToPostId!.isNotEmpty)
                    ? p.replyToPostId!
                    : rootPost.id;
            childrenMap.putIfAbsent(parentId, () => []).add(p);
          }

          final rootChildren = childrenMap[rootPost.id] ?? replyPosts;

          int countSubtreeReplies(FeedPost p) {
            final children = childrenMap[p.id] ?? [];
            int total = 0;
            for (final child in children) {
              if (!child.isDeleted) {
                total += 1 + countSubtreeReplies(child);
              }
            }
            return total;
          }

          CommentNode buildNode(FeedPost p) {
            final children = childrenMap[p.id] ?? [];
            final totalSubtree = countSubtreeReplies(p);
            final effectiveReplyCount = totalSubtree;
            final updatedChildPost = p.copyWith(
              replyCount: effectiveReplyCount,
              activeReplyCount: effectiveReplyCount,
            );
            return CommentNode(
              id: p.id,
              authorId: p.authorId,
              authorName: p.authorName,
              authorAvatarUrl: p.authorAvatarUrl,
              content: p.content,
              timestamp: _formatTimeAgo(p.createdAt),
              degree: p.degree,
              replyCount: effectiveReplyCount,
              isDeleted: p.isDeleted,
              isAnonymous: p.isAnonymous,
              post: updatedChildPost,
              replies: children.map<CommentNode>(buildNode).toList(),
            );
          }

          final int activeCount = rootPost.activeReplyCount;
          final int effectiveDegree = (rootPost.degree != 0 ||
                  rootPost.authorId == feedProvider.viewerId)
              ? rootPost.degree
              : widget.post.degree;
          final updatedRootPost = rootPost.copyWith(
            replyCount: activeCount,
            activeReplyCount: activeCount,
            degree: effectiveDegree,
          );
          final rootNode = CommentNode(
            id: rootPost.id,
            authorId: rootPost.authorId,
            authorName: rootPost.authorName,
            authorAvatarUrl: rootPost.authorAvatarUrl,
            content: rootPost.content,
            timestamp: _formatTimeAgo(rootPost.createdAt),
            degree: effectiveDegree,
            replyCount: activeCount,
            isDeleted: rootPost.isDeleted,
            isAnonymous: rootPost.isAnonymous,
            post: updatedRootPost,
            replies: rootChildren.map<CommentNode>(buildNode).toList(),
          );

          setState(() {
            _treeNode = rootNode;
            _isLoadingThread = false;
          });
          return;
        } else {
          setState(() {
            _treeNode = null;
            _isLoadingThread = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("[_FeedPostThreadItem] Error loading thread preview: $e");
    }

    if (mounted) {
      setState(() {
        _isLoadingThread = false;
      });
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  void _handleReactionToggle(String targetPostId, String selectedKey) {
    if (_treeNode != null) {
      CommentNode updateNode(CommentNode node) {
        if (node.id == targetPostId && node.post != null) {
          final currentPost = node.post!;
          final String? oldUserReaction = currentPost.userReaction;
          final Map<String, int> newCounts =
              Map<String, int>.from(currentPost.reactionCounts);

          String? newUserReaction;
          if (oldUserReaction == selectedKey) {
            newUserReaction = null;
            if (newCounts.containsKey(selectedKey)) {
              final c = newCounts[selectedKey]!;
              if (c <= 1) {
                newCounts.remove(selectedKey);
              } else {
                newCounts[selectedKey] = c - 1;
              }
            }
          } else {
            if (oldUserReaction != null &&
                newCounts.containsKey(oldUserReaction)) {
              final prevCount = newCounts[oldUserReaction]!;
              if (prevCount <= 1) {
                newCounts.remove(oldUserReaction);
              } else {
                newCounts[oldUserReaction] = prevCount - 1;
              }
            }
            newUserReaction = selectedKey;
            newCounts[selectedKey] = (newCounts[selectedKey] ?? 0) + 1;
          }

          final updatedPost = currentPost.copyWith(
            userReaction: newUserReaction,
            nullifyUserReaction: newUserReaction == null,
            reactionCounts: newCounts,
          );

          return node.copyWith(
            post: updatedPost,
            replies: node.replies.map(updateNode).toList(),
          );
        }

        return node.copyWith(
          replies: node.replies.map(updateNode).toList(),
        );
      }

      setState(() {
        _treeNode = updateNode(_treeNode!);
      });
    }

    final feedProvider = Provider.of<FeedProvider>(context, listen: false);
    feedProvider
        .toggleReaction(targetPostId, reactionType: selectedKey)
        .then((res) {
      if (res != null && mounted && _treeNode != null) {
        final serverReaction = res['user_reaction']?.toString();
        final Map<String, int> serverCounts = {};
        if (res['reaction_counts'] is Map) {
          (res['reaction_counts'] as Map).forEach((k, v) {
            final c = v is int ? v : (int.tryParse(v?.toString() ?? '') ?? 0);
            if (c > 0) serverCounts[k.toString()] = c;
          });
        }

        CommentNode applyServerUpdate(CommentNode node) {
          if (node.id == targetPostId && node.post != null) {
            final currentPost = node.post!;
            final updatedPost = currentPost.copyWith(
              userReaction: serverReaction,
              nullifyUserReaction: serverReaction == null,
              reactionCounts: serverCounts,
            );
            return node.copyWith(
              post: updatedPost,
              replies: node.replies.map(applyServerUpdate).toList(),
            );
          }
          return node.copyWith(
            replies: node.replies.map(applyServerUpdate).toList(),
          );
        }

        setState(() {
          _treeNode = applyServerUpdate(_treeNode!);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always resolve the latest post instance dynamically from FeedProvider
    final feedProvider = context.watch<FeedProvider>();
    final livePost = feedProvider.getPostById(widget.post.id) ?? widget.post;
    final effectivePost = livePost.copyWith(
      replyCount: livePost.activeReplyCount,
    );

    if (_treeNode != null && _treeNode!.replies.isNotEmpty) {
      final updatedTree = (_treeNode!.post?.reactionCounts != effectivePost.reactionCounts ||
              _treeNode!.post?.userReaction != effectivePost.userReaction)
          ? _treeNode!.copyWith(post: effectivePost)
          : _treeNode!;

      return ThreadedCommentTree(
        comment: updatedTree,
        parentAvatarRadius: 18.0,
        childAvatarRadius: 14.0,
        indentationWidth: 48.0,
        parentLeftPadding: 16.0,
        lineColor: const Color(0xFF3E414D),
        strokeWidth: 1.8,
        curveRadius: 12.0,
        allowNestedExpansion: false,
        onReactionToggle: _handleReactionToggle,
        onReplyTap: (node) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailPage(
                rootPostId: widget.post.id,
                highlightPostId: node.id,
                focusReplyToPostId: node.id,
              ),
            ),
          );
        },
        onCommentTap: (node) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailPage(
                rootPostId: widget.post.id,
                highlightPostId: node.id,
                focusReplyToPostId: node.id,
              ),
            ),
          );
        },
      );
    }

    return PostCard(
      post: effectivePost,
      onTap: widget.onTap,
      onReactionToggle: _handleReactionToggle,
    );
  }
}
