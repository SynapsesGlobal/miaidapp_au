import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/widget/marketing_product_card.dart';
import 'package:miaid/widget/product_media_gallery.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ProductMediaGallery.imagesOf / videoOf', () {
    test('reads the images array and the video url', () {
      const product = {
        'image': 'https://x/storage/products/a.png',
        'images': ['https://x/storage/products/a.png', 'https://x/storage/products/b.png'],
        'video': 'https://x/storage/products/videos/clip.mp4',
      };
      expect(ProductMediaGallery.imagesOf(product), ['https://x/storage/products/a.png', 'https://x/storage/products/b.png']);
      expect(ProductMediaGallery.videoOf(product), 'https://x/storage/products/videos/clip.mp4');
    });

    test('falls back to the single image field of the old api and treats empty video as none', () {
      expect(ProductMediaGallery.imagesOf({'image': 'https://x/one.png'}), ['https://x/one.png']);
      expect(ProductMediaGallery.imagesOf({'image': '', 'images': <String>[]}), isEmpty);
      expect(ProductMediaGallery.imagesOf({'images': <Object?>[null, '', 'https://x/c.png']}), ['https://x/c.png']);
      expect(ProductMediaGallery.videoOf({'video': ''}), isNull);
      expect(ProductMediaGallery.videoOf({}), isNull);
    });
  });

  group('ProductMediaGallery widget', () {
    testWidgets('shows a placeholder when the product has no media', (tester) async {
      await tester.pumpWidget(_host(ProductMediaGallery.fromProduct(const {'image': ''})));
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    });

    testWidgets('single image: no counter or dots', (tester) async {
      await tester.pumpWidget(_host(const ProductMediaGallery(images: ['https://x/a.png'])));
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('several images: counter and dots follow the swiped page', (tester) async {
      await tester.pumpWidget(_host(const ProductMediaGallery(
        images: ['https://x/a.png', 'https://x/b.png', 'https://x/c.png'],
      )));
      expect(find.text('1/3'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
      // Placeholder spinners animate forever, so pump a fixed duration rather than settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('2/3'), findsOneWidget);
    });
  });

  group('marketingProductImage', () {
    testWidgets('shows a play badge only when the product has a video', (tester) async {
      await tester.pumpWidget(_host(Column(children: [
        marketingProductImage(const {'image': '', 'video': 'https://x/clip.mp4'}, height: 80, width: 80),
        marketingProductImage(const {'image': ''}, height: 80, width: 80),
      ])));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });
}
