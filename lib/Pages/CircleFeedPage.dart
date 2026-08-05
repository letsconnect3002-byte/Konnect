import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connect/Config/app_theme.dart';
import 'package:connect/Providers/feed_provider.dart';
import 'package:connect/Providers/profile_provider.dart';
import 'package:connect/Providers/connection_provider.dart';
import 'package:connect/Pages/ThreadDetailPage.dart';
import 'package:connect/Models/feed_post.dart';
import 'package:connect/Widgets/post_card.dart';
import 'package:connect/Widgets/dwell_detector.dart';
import 'package:connect/Widgets/threaded_comment_tree.dart';
import 'package:connect/Widgets/link_preview_card.dart';
import 'package:connect/Widgets/pulse_row_widget.dart';
import 'package:connect/Providers/pulse_provider.dart';
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
                  Text(
                    "Shared with your network.",
                    style:
                        TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
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
                                  authorName: profileProvider.name,
                                  authorAvatarUrl: profileProvider.avatarUrl,
                                  connections: connections,
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
                          : const Text(
                              "Post to Network",
                              style: TextStyle(
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final feedProvider = Provider.of<FeedProvider>(context, listen: false);
      feedProvider.updateViewerId(profileProvider.userId);
    });
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = Provider.of<FeedProvider>(context);

    return Scaffold(
      backgroundColor: context.canvasBackground,
      appBar: AppBar(
        backgroundColor: context.canvasBackground,
        elevation: 0,
        centerTitle: false,
        title: Row(
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.edit_note_rounded,
        //         color: context.accentPrimary, size: 26),
        //     onPressed: () => _openComposeSheet(context),
        //   ),
        //   const SizedBox(width: 8),
        // ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/background/message background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.85,
              child: Container(
                decoration: BoxDecoration(
                  gradient: context.felineBackgroundGradient,
                ),
              ),
            ),
          ),
          feedProvider.isLoading && feedProvider.posts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
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
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  const PulseRowWidget(),
                                  Container(
                                    height: MediaQuery.of(context).size.height *
                                        0.6,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "No post shared by your network yet, be first to do so.",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _openComposeSheet(context),
                                          icon: const Icon(Icons.add_rounded,
                                              color: Colors.white, size: 18),
                                          label: const Text("Share First Post",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                context.accentPrimary,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: feedProvider.posts.length + 2,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return const PulseRowWidget();
                                }

                                if (index == feedProvider.posts.length + 1) {
                                  if (feedProvider.isLoadingMore) {
                                    return const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  return const SizedBox(height: 80);
                                }

                                final post = feedProvider.posts[index - 1];
                                final postIndex = index - 1;

                                final bool showDividerHere = feedProvider
                                        .hasShownCaughtUpDivider &&
                                    postIndex > 0 &&
                                    feedProvider.posts[postIndex - 1].degree ==
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
                                        key: ValueKey("feed_item_${post.id}"),
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

  @override
  void initState() {
    super.initState();
    if (widget.post.activeReplyCount > 0) {
      _loadThreadPreview();
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

    // Same post — sync the root node's post data (reactions, counts)
    // without re-fetching the entire thread.
    if (_treeNode != null) {
      setState(() {
        _treeNode = CommentNode(
          id: _treeNode!.id,
          authorId: _treeNode!.authorId,
          authorName: _treeNode!.authorName,
          authorAvatarUrl: _treeNode!.authorAvatarUrl,
          content: _treeNode!.content,
          timestamp: _treeNode!.timestamp,
          degree: _treeNode!.degree,
          replyCount: widget.post.activeReplyCount,
          isDeleted: _treeNode!.isDeleted,
          replyToName: _treeNode!.replyToName,
          post: widget.post.copyWith(
            replyCount: widget.post.activeReplyCount,
          ),
          replies: _treeNode!.replies,
        );
      });
    }

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

  Future<void> _loadThreadPreview() async {
    // Guard: don't re-fetch if we already fetched for this post
    if (_isLoadingThread || _lastFetchedPostId == widget.post.id) return;
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

          CommentNode buildNode(FeedPost p) {
            final children = childrenMap[p.id] ?? [];
            final activeChildren = children.where((c) => !c.isDeleted).length;
            final updatedChildPost = p.copyWith(replyCount: activeChildren);
            return CommentNode(
              id: p.id,
              authorId: p.authorId,
              authorName: p.authorName,
              authorAvatarUrl: p.authorAvatarUrl,
              content: p.content,
              timestamp: _formatTimeAgo(p.createdAt),
              degree: p.degree,
              replyCount: activeChildren,
              isDeleted: p.isDeleted,
              post: updatedChildPost,
              replies: children.map<CommentNode>(buildNode).toList(),
            );
          }

          // Use activeReplyCount from the widget's post (server-authoritative)
          final activeCount = widget.post.activeReplyCount;
          final updatedRootPost = rootPost.copyWith(replyCount: activeCount);
          final rootNode = CommentNode(
            id: rootPost.id,
            authorId: rootPost.authorId,
            authorName: rootPost.authorName,
            authorAvatarUrl: rootPost.authorAvatarUrl,
            content: rootPost.content,
            timestamp: _formatTimeAgo(rootPost.createdAt),
            degree: rootPost.degree,
            replyCount: activeCount,
            isDeleted: rootPost.isDeleted,
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

  @override
  Widget build(BuildContext context) {
    // Use activeReplyCount from the provider-owned post directly
    final effectivePost = widget.post.copyWith(
      replyCount: widget.post.activeReplyCount,
    );

    if (_treeNode != null && _treeNode!.replies.isNotEmpty) {
      return ThreadedCommentTree(
        comment: _treeNode!,
        parentAvatarRadius: 18.0,
        childAvatarRadius: 14.0,
        indentationWidth: 48.0,
        parentLeftPadding: 16.0,
        lineColor: Colors.white.withValues(alpha: 0.25),
        strokeWidth: 1.8,
        curveRadius: 12.0,
        allowNestedExpansion: false,
        onReplyTap: (node) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailPage(
                rootPostId: widget.post.id,
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
              ),
            ),
          );
        },
      );
    }

    return PostCard(
      post: effectivePost,
      onTap: widget.onTap,
    );
  }
}
