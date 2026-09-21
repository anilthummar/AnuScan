import 'package:equatable/equatable.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();

  @override
  List<Object?> get props => [];
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();
}

class ScannerScanning extends ScannerState {
  const ScannerScanning();
}

class ScannerImporting extends ScannerState {
  const ScannerImporting();
}

class ScannerSuccess extends ScannerState {
  const ScannerSuccess(this.imagePaths);

  final List<String> imagePaths;

  @override
  List<Object?> get props => [imagePaths];
}

class ScannerCancelled extends ScannerState {
  const ScannerCancelled();
}

class ScannerError extends ScannerState {
  const ScannerError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
