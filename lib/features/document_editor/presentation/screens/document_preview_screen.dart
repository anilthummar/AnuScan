import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../document_history/domain/entities/document_entity.dart';
import '../screens/page_editor_screen.dart';

/// Screen for previewing document metadata, page list, and navigating to editor or export.
class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({super.key, this.document});

  final DocumentEntity? document;

  @override
  Widget build(BuildContext context) {
    final doc = document;

    return Scaffold(
      appBar: AppBar(title: Text(doc?.title ?? 'Document Preview')),
      body: doc == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Document Selected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a document from your history or scan pages to preview.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${doc.pages.length} Pages • Created: ${doc.createdAt.toLocal().toString().split('.')[0]}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: doc.pages.length,
                  itemBuilder: (context, index) {
                    final page = doc.pages[index];
                    final file = File(page.processedImagePath);
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PageEditorScreen(page: page),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : const ColoredBox(
                                    color: Colors.black12,
                                    child: Center(
                                      child: Icon(Icons.broken_image),
                                    ),
                                  ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
