import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuscan/app.dart';
import 'package:anuscan/core/di/injection.dart';
import 'package:anuscan/features/document_history/domain/repositories/document_repository.dart';
import 'package:anuscan/features/document_history/domain/entities/document_entity.dart';

class MockDocumentRepository implements DocumentRepository {
  @override
  Future<List<DocumentEntity>> getAllDocuments() async => [];

  @override
  Future<DocumentEntity?> getDocumentById(String id) async => null;

  @override
  Future<void> saveDocument(DocumentEntity document) async {}

  @override
  Future<void> deleteDocument(String id) async {}

  @override
  Future<void> renameDocument(String id, String newTitle) async {}

  @override
  Future<List<DocumentEntity>> searchDocuments(String query) async => [];
}

void main() {
  setUp(() async {
    await setupDependencyInjection(
      customDocumentRepository: MockDocumentRepository(),
    );
  });

  testWidgets('AnuScanApp renders HomeScreen successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AnuScanApp());
    await tester.pump();

    // Verify app title is displayed in AppBar
    expect(find.text('AnuScan'), findsOneWidget);

    // Verify FloatingActionButton exists with label Scan
    expect(find.text('Scan'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsAtLeastNWidgets(1));
  });
}
