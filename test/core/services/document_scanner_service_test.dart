import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:anuscan/core/errors/exceptions.dart';
import 'package:anuscan/core/services/document_scanner_service.dart';

class FakePermissionHandlerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {
  FakePermissionHandlerPlatform({required this.status});

  PermissionStatus status;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    return status;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    return {for (final p in permissions) p: status};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePermissionHandlerPlatform fakePermissionPlatform;

  setUp(() {
    fakePermissionPlatform = FakePermissionHandlerPlatform(
      status: PermissionStatus.granted,
    );
    PermissionHandlerPlatform.instance = fakePermissionPlatform;
  });

  test('initial state has uninitialized controller and flash off', () {
    final service = DocumentScannerServiceImpl();
    expect(service.isInitialized, isFalse);
    expect(service.isFlashOn, isFalse);
    expect(service.currentCorners, isNull);
  });

  test(
    'captureDocument throws ScannerException when not initialized',
    () async {
      final service = DocumentScannerServiceImpl();
      expect(() => service.captureDocument(), throwsA(isA<ScannerException>()));
    },
  );

  test('toggleFlash returns false when not initialized', () async {
    final service = DocumentScannerServiceImpl();
    final flash = await service.toggleFlash();
    expect(flash, isFalse);
  });

  test('checkPermission returns true when permission is granted', () async {
    final service = DocumentScannerServiceImpl();
    final granted = await service.checkPermission();
    expect(granted, isTrue);
  });

  test('checkPermission returns false when permission is denied', () async {
    fakePermissionPlatform.status = PermissionStatus.denied;
    final service = DocumentScannerServiceImpl();
    final granted = await service.checkPermission();
    expect(granted, isFalse);
  });

  test(
    'initialize throws PermissionException when permission is denied',
    () async {
      fakePermissionPlatform.status = PermissionStatus.denied;
      final service = DocumentScannerServiceImpl();

      expect(() => service.initialize(), throwsA(isA<PermissionException>()));
    },
  );

  test(
    'initialize throws ScannerException when no cameras are available',
    () async {
      fakePermissionPlatform.status = PermissionStatus.granted;
      final service = DocumentScannerServiceImpl(availableCamerasList: []);

      expect(() => service.initialize(), throwsA(isA<ScannerException>()));
    },
  );

  test('dispose safely closes streams and resets state', () async {
    final service = DocumentScannerServiceImpl();
    await service.dispose();
    expect(service.isInitialized, isFalse);
    expect(service.currentCorners, isNull);
  });
}
