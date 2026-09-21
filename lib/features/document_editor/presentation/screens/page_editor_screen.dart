import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/file_storage_service.dart';
import '../../../../core/services/image_processing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/scanned_page.dart';
import '../../domain/usecases/process_page_usecase.dart';
import '../cubit/page_editor_cubit.dart';
import '../cubit/page_editor_state.dart';
import '../widgets/filter_selector_bar.dart';
import 'perspective_crop_screen.dart';

/// Screen for editing an individual document page (Filter, Rotation, Corner Perspective).
class PageEditorScreen extends StatelessWidget {
  const PageEditorScreen({
    super.key,
    required this.page,
  });

  final ScannedPage page;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PageEditorCubit(
        initialPage: page,
        processPageUseCase: ProcessPageUseCase(
          imageProcessingService: sl<ImageProcessingService>(),
          fileStorageService: sl<FileStorageService>(),
        ),
      ),
      child: const _PageEditorView(),
    );
  }
}

class _PageEditorView extends StatelessWidget {
  const _PageEditorView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PageEditorCubit, PageEditorState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<PageEditorCubit>();

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              'Edit Page ${state.currentPage.pageIndex + 1}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (state.hasUnsavedChanges)
                IconButton(
                  tooltip: 'Reset to Original',
                  icon: const Icon(Icons.undo),
                  onPressed: state.isProcessing ? null : () => cubit.resetToOriginal(),
                ),
              TextButton(
                onPressed: state.isProcessing
                    ? null
                    : () {
                        Navigator.pop(context, state.currentPage);
                      },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Main Interactive Preview
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.file(
                          File(state.currentPage.processedImagePath),
                          fit: BoxFit.contain,
                          // Keyed on path and timestamp so Flutter cache updates immediately
                          key: ValueKey(
                            '${state.currentPage.processedImagePath}_${state.selectedFilter}_${state.currentRotation}',
                          ),
                        ),
                      ),
                      if (state.isProcessing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Processing...',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Editing Control Bar
              Container(
                color: AppColors.surfaceDark,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Action icons: Crop / Perspective & Rotate
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.crop,
                            label: 'Crop / Perspective',
                            onTap: state.isProcessing
                                ? null
                                : () async {
                                    final updatedCorners = await Navigator.push<DocumentCornerPoints>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PerspectiveCropScreen(
                                          page: state.currentPage,
                                        ),
                                      ),
                                    );
                                    if (updatedCorners != null && context.mounted) {
                                      cubit.setCorners(updatedCorners);
                                    }
                                  },
                          ),
                          _ActionButton(
                            icon: Icons.rotate_right,
                            label: 'Rotate',
                            onTap: state.isProcessing
                                ? null
                                : () => cubit.rotateClockwise(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    // Filter Options
                    FilterSelectorBar(
                      selectedFilter: state.selectedFilter,
                      enabled: !state.isProcessing,
                      onFilterSelected: (filter) => cubit.setFilter(filter),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap != null ? Colors.white : Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? Colors.white70 : Colors.white30,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
