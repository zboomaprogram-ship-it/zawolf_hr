import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zawolf_hr/features/conversations/data/media/chat_media_gateway_impl.dart';

void main() {
  test('chat images are bounded and receive a small preview', () {
    final source = img.Image(width: 2400, height: 1800);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, x % 255, y % 255, (x + y) % 255, 255);
      }
    }

    final result = optimizeChatImage(Uint8List.fromList(img.encodePng(source)));
    final optimized = img.decodeImage(result['image']!);

    expect(optimized, isNotNull);
    expect(optimized!.width, lessThanOrEqualTo(1920));
    expect(optimized.height, lessThanOrEqualTo(1920));
    expect(result['image']!.length, lessThanOrEqualTo(800 * 1024));
    expect(result['thumbnail']!.length, lessThanOrEqualTo(10 * 1024));
  });
}
