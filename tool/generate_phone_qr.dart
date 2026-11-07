import 'dart:io';

import 'package:qr/qr.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    throw ArgumentError(
      'Usage: dart run tool/generate_phone_qr.dart <app-url> [output.svg]',
    );
  }

  final uri = Uri.parse(arguments.first);
  if (!uri.hasScheme ||
      !uri.hasAuthority ||
      !const {'http', 'https'}.contains(uri.scheme)) {
    throw ArgumentError.value(arguments.first, 'app-url', 'Invalid URL');
  }

  final code = QrCode(
    payload: QrPayload.fromString(uri.toString()),
    errorCorrectLevel: QrErrorCorrectLevel.high,
  );
  final image = QrImage(code);
  const quietZone = 4;
  final size = image.moduleCount + quietZone * 2;
  final path = StringBuffer();

  for (var row = 0; row < image.moduleCount; row++) {
    for (var column = 0; column < image.moduleCount; column++) {
      if (image.isDark(row, column)) {
        path.write('M${column + quietZone} ${row + quietZone}h1v1h-1z');
      }
    }
  }

  final svg =
      '''
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 $size $size" shape-rendering="crispEdges">
<rect width="$size" height="$size" fill="#fff"/>
<path d="$path" fill="#000"/>
</svg>
''';
  final output = arguments.length == 2
      ? File(arguments[1])
      : File('voltora-phone-qr.svg');
  output.writeAsStringSync(svg);
  stdout.writeln('QR code saved to ${output.path} for ${uri.toString()}');
}
