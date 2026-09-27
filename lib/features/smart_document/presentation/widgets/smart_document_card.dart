import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/document_classification.dart';
import '../../domain/entities/document_metadata.dart';
import '../cubit/smart_document_cubit.dart';
import '../cubit/smart_document_state.dart';

/// Reusable card displaying smart document recognition, classification badge,
/// suggested filename action, and extracted metadata drawer.
class SmartDocumentCard extends StatefulWidget {
  const SmartDocumentCard({
    super.key,
    required this.currentTitle,
    required this.onApplyName,
    this.onEditName,
  });

  final String currentTitle;
  final ValueChanged<String> onApplyName;
  final VoidCallback? onEditName;

  @override
  State<SmartDocumentCard> createState() => _SmartDocumentCardState();
}

class _SmartDocumentCardState extends State<SmartDocumentCard> {
  bool _isExpanded = false;

  void _showTypeSelector(BuildContext context, DocumentType currentType) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Document Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: DocumentType.values.map((type) {
                    final isSelected = type == currentType;
                    return ListTile(
                      leading: Icon(
                        _getTypeIcon(type),
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(
                        type.displayName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        context.read<SmartDocumentCubit>().overrideDocumentType(
                          type,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMetadataDialog(
    BuildContext context,
    DocumentMetadata metadata,
  ) {
    final companyCtrl = TextEditingController(text: metadata.companyName ?? '');
    final numberCtrl = TextEditingController(
      text: metadata.primaryIdentifier ?? '',
    );
    final dateCtrl = TextEditingController(text: metadata.date ?? '');
    final amountCtrl = TextEditingController(text: metadata.amountText ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Extracted Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Company / Vendor',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document / Invoice #',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Date'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount / Total'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = metadata.copyWith(
                companyName: companyCtrl.text.trim().isNotEmpty
                    ? companyCtrl.text.trim()
                    : null,
                documentNumber: numberCtrl.text.trim().isNotEmpty
                    ? numberCtrl.text.trim()
                    : null,
                date: dateCtrl.text.trim().isNotEmpty
                    ? dateCtrl.text.trim()
                    : null,
                amountText: amountCtrl.text.trim().isNotEmpty
                    ? amountCtrl.text.trim()
                    : null,
                source: ProvenanceSource.manual,
              );
              context.read<SmartDocumentCubit>().updateMetadata(updated);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SmartDocumentCubit, SmartDocumentState>(
      builder: (context, state) {
        if (state is SmartDocumentLoading) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Analyzing document...',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is! SmartDocumentSuccess) {
          return const SizedBox.shrink();
        }

        final result = state.result;
        final classification = result.classification;
        final metadata = result.metadata;
        final suggested = result.suggestedFilename;
        final isApplied =
            state.isNameApplied || widget.currentTitle == suggested;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Type Badge + Manual Override Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () =>
                          _showTypeSelector(context, classification.type),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(classification.type),
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              classification.type.displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      classification.source == ProvenanceSource.manual
                          ? 'Manual'
                          : 'Detected from text',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Suggested Filename Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Suggested Filename',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            suggested,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Action Buttons Row: [Use Suggested Name] or [Applied]
                Row(
                  children: [
                    if (!isApplied)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Use Suggested Name'),
                        onPressed: () {
                          widget.onApplyName(suggested);
                          context.read<SmartDocumentCubit>().markNameApplied();
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Name Applied',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    if (widget.onEditName != null)
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: widget.onEditName,
                      ),
                    IconButton(
                      icon: Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      tooltip: _isExpanded ? 'Hide metadata' : 'Show metadata',
                    ),
                  ],
                ),

                // Expandable Metadata Summary Drawer
                if (_isExpanded) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Extracted Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showEditMetadataDialog(context, metadata),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            'Edit Details',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (metadata.companyName != null)
                    _buildMetadataRow('Company / Store', metadata.companyName!),
                  if (metadata.personName != null)
                    _buildMetadataRow('Person Name', metadata.personName!),
                  if (metadata.primaryIdentifier != null)
                    _buildMetadataRow(
                      'Document / Inv #',
                      metadata.primaryIdentifier!,
                    ),
                  if (metadata.date != null)
                    _buildMetadataRow('Date', metadata.date!),
                  if (metadata.amountText != null)
                    _buildMetadataRow('Total Amount', metadata.amountText!),
                  if (metadata.email != null)
                    _buildMetadataRow('Email', metadata.email!),
                  if (metadata.phone != null)
                    _buildMetadataRow('Phone', metadata.phone!),
                  if (metadata.website != null)
                    _buildMetadataRow('Website', metadata.website!),
                  if (metadata.isEmpty)
                    const Text(
                      'No specific metadata identified',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _getTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return Icons.receipt_long;
      case DocumentType.receipt:
        return Icons.receipt;
      case DocumentType.businessCard:
        return Icons.badge;
      case DocumentType.identityDocument:
        return Icons.perm_identity;
      case DocumentType.form:
        return Icons.description;
      case DocumentType.certificate:
        return Icons.workspace_premium;
      case DocumentType.letter:
        return Icons.mail;
      case DocumentType.report:
        return Icons.assessment;
      case DocumentType.notes:
        return Icons.note_alt;
      case DocumentType.contract:
        return Icons.history_edu;
      case DocumentType.bankStatement:
        return Icons.account_balance;
      case DocumentType.medicalDocument:
        return Icons.medical_information;
      case DocumentType.taxDocument:
        return Icons.request_quote;
      case DocumentType.other:
        return Icons.article;
    }
  }
}
