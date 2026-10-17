import 'dart:io';

void main(List<String> args) {
  final root = Directory.current;

  // Search candidate paths
  Directory? kitDir;
  final candidates = [
    if (args.isNotEmpty) args[0],
    'E:/Projects/MoluMulk_eBozor_Complete_Developer_Kit 1/eBozor',
    '${root.parent.path}/MoluMulk_eBozor_Complete_Developer_Kit 1/eBozor',
    '${root.path}/MoluMulk_eBozor_Complete_Developer_Kit 1/eBozor',
  ];

  for (final path in candidates) {
    if (path == null) continue;
    final dir = Directory(path);
    if (dir.existsSync()) {
      kitDir = dir;
      break;
    }
    final nested = Directory('$path/eBozor');
    if (nested.existsSync()) {
      kitDir = nested;
      break;
    }
  }

  if (kitDir == null) {
    print('[ERROR] Developer Kit not found. Checked:');
    for (final c in candidates) {
      if (c != null) print(' - $c');
    }
    return;
  }

  print('Found brand kit at: ${kitDir.path}');
  print('Syncing eBozor official brand assets...');

  // 1. Android Resources
  final androidResSrc = Directory('${kitDir.path}/05_Android/res');
  final androidResDest = Directory('${root.path}/android/app/src/main/res');
  if (androidResSrc.existsSync()) {
    _copyDirectory(androidResSrc, androidResDest);
    print('✓ Android launcher mipmap icons synced.');
  }

  // 2. iOS Icons
  final iosSrc = Directory('${kitDir.path}/04_iOS/AppIcon.appiconset');
  final iosDest = Directory('${root.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  if (iosSrc.existsSync()) {
    if (!iosDest.existsSync()) iosDest.createSync(recursive: true);
    _copyDirectory(iosSrc, iosDest);
    print('✓ iOS AppIcon.appiconset synced.');
  }

  // 3. In-App Flutter Assets (assets/svg/Logo/)
  final logoDest = Directory('${root.path}/assets/svg/Logo');
  if (!logoDest.existsSync()) logoDest.createSync(recursive: true);

  final webLogosSrc = Directory('${kitDir.path}/01_Web_Logos');
  if (webLogosSrc.existsSync()) {
    _copyFile('${webLogosSrc.path}/logo-540w.png', '${logoDest.path}/ebozor_logo.png');
    _copyFile('${webLogosSrc.path}/logo-master-white.png', '${logoDest.path}/ebozor_logo_master.png');
    _copyFile('${webLogosSrc.path}/logo-360w.png', '${logoDest.path}/ebozor_logo_360.png');
  }

  final symbolSrc = File('${kitDir.path}/06_Reference/symbol-source-white.png');
  if (symbolSrc.existsSync()) {
    _copyFile(symbolSrc.path, '${logoDest.path}/splashlogo.png');
    _copyFile(symbolSrc.path, '${logoDest.path}/ebozor_symbol.png');
  }

  final appMaster = File('${kitDir.path}/05_Android/app-master-1024.png');
  if (appMaster.existsSync()) {
    _copyFile(appMaster.path, '${logoDest.path}/applogo.png');
    _copyFile(appMaster.path, '${logoDest.path}/1024.png');
  }
  print('✓ Flutter app logos and splash icons synced.');

  // 4. Web Assets
  final faviconSrc = Directory('${kitDir.path}/02_Favicon');
  final webDest = Directory('${root.path}/web');
  if (faviconSrc.existsSync() && webDest.existsSync()) {
    _copyFile('${faviconSrc.path}/favicon.ico', '${webDest.path}/favicon.ico');
    _copyFile('${faviconSrc.path}/favicon-32.png', '${webDest.path}/favicon.png');
  }

  final mobileWebSrc = Directory('${kitDir.path}/03_Mobile_Web');
  final webIconsDest = Directory('${root.path}/web/icons');
  if (mobileWebSrc.existsSync()) {
    if (!webIconsDest.existsSync()) webIconsDest.createSync(recursive: true);
    _copyFile('${mobileWebSrc.path}/icon-192.png', '${webIconsDest.path}/Icon-192.png');
    _copyFile('${mobileWebSrc.path}/icon-512.png', '${webIconsDest.path}/Icon-512.png');
    _copyFile('${mobileWebSrc.path}/maskable-512.png', '${webIconsDest.path}/Icon-maskable-512.png');
    print('✓ Web favicons and PWA icons synced.');
  }

  print('\nAll official eBozor brand assets successfully synchronized!');
}

void _copyFile(String srcPath, String destPath) {
  final src = File(srcPath);
  if (src.existsSync()) {
    final dest = File(destPath);
    if (!dest.parent.existsSync()) {
      dest.parent.createSync(recursive: true);
    }
    src.copySync(destPath);
  }
}

void _copyDirectory(Directory src, Directory dest) {
  for (final entity in src.listSync(recursive: true)) {
    if (entity is File) {
      final relativePath = entity.path.substring(src.path.length + 1);
      final targetPath = '${dest.path}/$relativePath';
      final targetFile = File(targetPath);
      if (!targetFile.parent.existsSync()) {
        targetFile.parent.createSync(recursive: true);
      }
      entity.copySync(targetPath);
    }
  }
}
