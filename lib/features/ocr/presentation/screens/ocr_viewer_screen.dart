import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/share_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../document_editor/domain/entities/scanned_page.dart';
import '../../domain/usecases/ocr_usecases.dart';
import '../cubit/ocr_cubit.dart';
import '../cubit/ocr_state.dart';

/// Screen displaying extracted document OCR text with search, copy, and export capabilities.
class OcrViewerScreen extends StatelessWidget {
  const OcrViewerScreen({
    super.key,
    required this.documentId,
    required this.title,
    required this.pages,
    this.customCubit,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;
  final OcrCubit? customCubit;

  @override
  Widget build(BuildContext context) {
    if (customCubit != null) {
      return BlocProvider.value(
        value: customCubit!,
        child: _OcrViewerView(
          documentId: documentId,
          title: title,
          pages: pages,
        ),
      );
    }

    return BlocProvider(
      create: (context) {
        final cubit = OcrCubit(
          extractDocumentTextUseCase: sl<ExtractDocumentTextUseCase>(),
          getDocumentOcrUseCase: sl<GetDocumentOcrUseCase>(),
          searchDocumentTextUseCase: sl<SearchDocumentTextUseCase>(),
        );
        cubit.loadOrExtract(documentId: documentId, pages: pages);
        return cubit;
      },
      child: _OcrViewerView(documentId: documentId, title: title, pages: pages),
    );
  }
}

class _OcrViewerView extends StatefulWidget {
  const _OcrViewerView({
    required this.documentId,
    required this.title,
    required this.pages,
  });

  final String documentId;
  final String title;
  final List<ScannedPage> pages;

  @override
  State<_OcrViewerView> createState() => _OcrViewerViewState();
}

class _OcrViewerViewState extends State<_OcrViewerView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _pageKeys = {};
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPage(int pageIndex) {
    final key = _pageKeys[pageIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _copyFullText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareText(String text) async {
    final shareService = sl<ShareService>();
    await shareService.shareText(
      text,
      subject: '${widget.title} — Extracted Text',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search in document...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      context.read<OcrCubit>().clearSearch();
                    },
                  ),
                ),
                onChanged: (val) {
                  context.read<OcrCubit>().searchWithin(val);
                },
              )
            : Text(widget.title),
        actions: [
          BlocBuilder<OcrCubit, OcrState>(
            builder: (context, state) {
              if (state is! OcrSuccess) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _isSearching ? 'Close Search' : 'Search Text',
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          context.read<OcrCubit>().clearSearch();
                        }
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Copy All Text',
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyFullText(state.result.combinedText),
                  ),
                  IconButton(
                    tooltip: 'Share Text',
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareText(state.result.combinedText),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<OcrCubit, OcrState>(
        builder: (context, state) {
          // 1. Initial or Loading
          if (state is OcrInitial || state is OcrLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Preparing document text...',
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            );
          }

          // 2. Active OCR Progress
          if (state is OcrProgress) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      state.statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: state.progress > 0 ? state.progress : null,
                      backgroundColor: Colors.black12,
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(state.progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel'),
                      onPressed: () => context.read<OcrCubit>().cancel(),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. Failure State
          if (state is OcrFailure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 56,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Text Extraction Failed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () {
                        context.read<OcrCubit>().loadOrExtract(
                              documentId: widget.documentId,
                              pages: widget.pages,
                              force: true,
                            );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // 4. Cancelled State
          if (state is OcrCancelled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 56,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Text Extraction Cancelled',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.partialResults.isNotEmpty
                          ? 'Extracted ${state.partialResults.length} pages before cancellation.'
                          : 'No text extracted.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume Extraction'),
                      onPressed: () {
                        context.read<OcrCubit>().loadOrExtract(
                              documentId: widget.documentId,
                              pages: widget.pages,
                              force: true,
                            );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // 5. Success State
          if (state is OcrSuccess) {
            final docResult = state.result;

            if (!docResult.hasText) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.text_snippet_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Text Detected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The scanned pages appear to contain only drawings, blank areas, or low contrast content.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Re-scan Pages'),
                        onPressed: () {
                          context.read<OcrCubit>().loadOrExtract(
                                documentId: widget.documentId,
                                pages: widget.pages,
                                force: true,
                              );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                // Top Info & Search Summary Bar
                Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${docResult.pageCount} Pages • ${docResult.totalWordCount} words',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (state.isFromCache)
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Cached',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      IconButton(
                        tooltip: 'Re-extract OCR',
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: () {
                          context.read<OcrCubit>().loadOrExtract(
                                documentId: widget.documentId,
                                pages: widget.pages,
                                force: true,
                              );
                        },
                      ),
                    ],
                  ),
                ),

                // In-Document Search Matches Header
                if (state.activeSearchQuery != null &&
                    state.activeSearchQuery!.isNotEmpty)
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.searchMatches.isEmpty
                                    ? 'No matches for "${state.activeSearchQuery}"'
                                    : '${state.searchMatches.fold<int>(0, (s, m) => s + m.matchCount)} matches across ${state.searchMatches.length} pages',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (state.searchMatches.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: state.searchMatches.map((m) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      'Page ${m.pageIndex + 1} (${m.matchCount})',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () => _scrollToPage(m.pageIndex),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // Continuous Document Pages Text View
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: docResult.pageResults.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Divider(thickness: 1.5, color: Colors.black12),
                    ),
                    itemBuilder: (context, index) {
                      final page = docResult.pageResults[index];
                      _pageKeys[page.pageIndex] = GlobalKey();

                      return Container(
                        key: _pageKeys[page.pageIndex],
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Page ${page.pageIndex + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${page.wordCount} words',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: 'Copy page text',
                                      onPressed: () =>
                                          _copyFullText(page.extractedText),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              page.hasText
                                  ? page.extractedText.trim()
                                  : '[No text detected on this page]',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: page.hasText
                                    ? AppColors.textPrimaryLight
                                    : Colors.grey,
                                fontStyle: page.hasText
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
