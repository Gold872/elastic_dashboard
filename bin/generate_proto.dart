// ignore_for_file: avoid_print

import 'dart:io';

void main() async {
  if (!await _isProtocInstalled()) {
    _printProtocMissingInstructions();
    exit(1);
  }

  if (!await _isProtocPluginInstalled()) {
    _printPluginMissingInstructions();
    exit(1);
  }

  final protoDir = Directory('proto');
  final outDir = Directory('lib/generated');

  if (!protoDir.existsSync()) {
    print('Error: "proto" directory not found at project root.');
    print('Please create a "proto" folder and place your .proto files there.');
    exit(1);
  }

  if (!outDir.existsSync()) {
    print('Creating directory: ${outDir.path}');
    outDir.createSync(recursive: true);
  }

  // Get all .proto files in the proto directory
  final protoFiles = protoDir
      .listSync()
      .where((file) => file is File && file.path.endsWith('.proto'))
      .map((file) => file.path)
      .toList();

  if (protoFiles.isEmpty) {
    print('No .proto files found in "proto" directory.');
    return;
  }

  print(
    'Generating Dart files for: ${protoFiles.join(', ').replaceAll('\\', '/')}',
  );

  // Run the protoc command
  final result = await Process.run('protoc', [
    '--dart_out=lib/generated',
    '-Iproto',
    ...protoFiles,
  ]);

  if (result.exitCode == 0) {
    print('Successfully generated Protobuf classes in lib/generated/');
  } else {
    print('Error generating Protobuf classes:');
    print(result.stderr);
    print(result.stdout);
    exit(1);
  }
}

Future<bool> _isProtocInstalled() async {
  try {
    final result = await Process.run('protoc', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<bool> _isProtocPluginInstalled() async {
  // protoc looks for a binary named 'protoc-gen-dart' in the PATH
  final command = Platform.isWindows ? 'where' : 'which';
  try {
    final result = await Process.run(command, ['protoc-gen-dart']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void _printProtocMissingInstructions() {
  print(
    'Error: "protoc" (Protobuf Compiler) is not installed or not in your PATH.',
  );
  print('\nTo install protoc:');
  print(
    '1. Download the latest release from: https://github.com/protocolbuffers/protobuf/releases',
  );
  print('2. Extract the "bin" folder and add it to your system PATH.');
  print('   - On Windows: Search for "Edit the system environment variables".');
  print('   - On macOS/Linux: Add to your .bashrc or .zshrc.');
}

void _printPluginMissingInstructions() {
  print(
    'Error: "protoc-gen-dart" (Dart Protobuf Plugin) is not installed or not in your PATH.',
  );
  print('\nTo install the plugin:');
  print('1. Run: dart pub global activate protoc_plugin');
  print('2. Ensure your Dart/Pub cache bin directory is in your PATH:');
  if (Platform.isWindows) {
    print('   - Typically: %USERPROFILE%\\AppData\\Local\\Pub\\Cache\\bin');
  } else {
    print('   - Typically: \$HOME/.pub-cache/bin');
  }
}
