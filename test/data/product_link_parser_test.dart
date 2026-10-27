import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/remote/product_link_service.dart';

void main() {
  group('ProductPageParser.findUrl', () {
    test('finds the link inside a share message', () {
      final url = ProductPageParser.findUrl(
        'Xem sản phẩm này nè https://s.shopee.vn/AbC123 giá tốt',
      );
      expect(url.toString(), 'https://s.shopee.vn/AbC123');
    });

    test('adds https to a bare domain', () {
      expect(
        ProductPageParser.findUrl('www.zara.com/vn/en/shirt-p123.html')
            .toString(),
        'https://www.zara.com/vn/en/shirt-p123.html',
      );
    });

    test('rejects text that is not a link', () {
      expect(ProductPageParser.findUrl('white linen shirt'), isNull);
      expect(ProductPageParser.findUrl(''), isNull);
    });
  });

  group('ProductPageParser.parse', () {
    final page = Uri.parse('https://shop.example.com/p/linen-shirt');

    test('reads schema.org Product data first', () {
      const html = '''
<html><head>
<meta property="og:title" content="Wrong title">
<script type="application/ld+json">
{"@context":"https://schema.org","@graph":[
  {"@type":"BreadcrumbList"},
  {"@type":"Product","name":"Linen Shirt &amp; Tie",
   "image":["/img/shirt.jpg"],
   "brand":{"@type":"Brand","name":"Uniqlo"},
   "offers":{"@type":"Offer","price":"499000","priceCurrency":"VND"}}
]}
</script></head></html>''';
      final result = ProductPageParser.parse(html, page);
      expect(result.name, 'Linen Shirt & Tie');
      expect(result.brand, 'Uniqlo');
      expect(result.price, 499000);
      expect(result.currency, 'VND');
      expect(
        result.imageUrl.toString(),
        'https://shop.example.com/img/shirt.jpg',
      );
    });

    test('falls back to Open Graph and product meta tags', () {
      const html = '''
<head>
<meta content="Áo thun basic | Shopee Việt Nam" property="og:title" />
<meta property="og:site_name" content="Shopee Việt Nam">
<meta property="og:image" content="//cf.shopee.vn/file/abc">
<meta property="product:price:amount" content="159.000">
<meta property="product:price:currency" content="VND">
</head>''';
      final result = ProductPageParser.parse(
        html,
        Uri.parse('https://shopee.vn/ao-thun-i.1.2'),
      );
      expect(result.name, 'Áo thun basic');
      // A marketplace's site name is not the brand.
      expect(result.brand, isNull);
      expect(result.price, 159000);
      expect(result.imageUrl.toString(), 'https://cf.shopee.vn/file/abc');
    });

    test('uses a brand store’s site name as the brand', () {
      const html = '''
<meta property="og:site_name" content="ZARA">
<meta property="og:title" content="Oversize blazer - ZARA">
<title>ignored</title>''';
      final result = ProductPageParser.parse(
        html,
        Uri.parse('https://www.zara.com/vn/en/blazer-p1.html'),
      );
      expect(result.brand, 'ZARA');
      expect(result.name, 'Oversize blazer');
    });

    test('uses the page title when nothing else names the piece', () {
      final result = ProductPageParser.parse(
        '<title>  Denim jacket\n</title>',
        page,
      );
      expect(result.name, 'Denim jacket');
      expect(result.isEmpty, isFalse);
    });

    test('a page without details is empty', () {
      expect(ProductPageParser.parse('<html></html>', page).isEmpty, isTrue);
    });

    test('survives broken JSON-LD', () {
      const html = '''
<script type="application/ld+json">{not json</script>
<meta name="twitter:title" content="Cargo pants">''';
      expect(ProductPageParser.parse(html, page).name, 'Cargo pants');
    });

    test('keeps long names within the form limit', () {
      final long = List.filled(60, 'word').join(' ');
      final name = ProductPageParser.parse(
        '<meta property="og:title" content="$long">',
        page,
      ).name!;
      expect(name.length, lessThanOrEqualTo(120));
      expect(name.endsWith(' '), isFalse);
    });

    test('keeps a shop’s full product name, variant included', () {
      // As yame.vn serves it: a ProductGroup, and og tags without the
      // variant and with an http image.
      const html = '''
<meta property="og:title" content="Áo Thun Cổ Tròn FlexFit™ Vải Single Co Giãn In Typography Phom Vừa F3 ">
<meta property="og:site_name" content="YaMe.vn">
<meta property="og:image" content="http://yame.vn/cdn/shop/files/a.jpg?v=1">
<script type="application/ld+json">
{"@context":"http://schema.org/","@type":"ProductGroup",
 "name":"Áo Thun Cổ Tròn FlexFit™ Vải Single Co Giãn In Typography Phom Vừa F3 - The Weekend 097 Nâu Đậm",
 "brand":{"@type":"Brand","name":"YaMe"},
 "hasVariant":[{"@type":"Product","name":"S Áo Thun",
   "offers":{"@type":"Offer","price":252450.0,"priceCurrency":"VND"}}]}
</script>''';
      final result = ProductPageParser.parse(
        html,
        Uri.parse('https://yame.vn/products/ao-thun-2625407'),
      );
      expect(
        result.name,
        'Áo Thun Cổ Tròn FlexFit™ Vải Single Co Giãn In Typography Phom Vừa '
        'F3 - The Weekend 097 Nâu Đậm',
      );
      expect(result.brand, 'YaMe');
      expect(result.price, 252450);
      expect(
        result.imageUrl.toString(),
        'https://yame.vn/cdn/shop/files/a.jpg?v=1',
      );
    });
  });

  group('ProductPageParser.parsePrice', () {
    test('reads common price formats', () {
      expect(ProductPageParser.parsePrice('499000'), 499000);
      expect(ProductPageParser.parsePrice('499.000 ₫'), 499000);
      expect(ProductPageParser.parsePrice('1.299.000đ'), 1299000);
      expect(ProductPageParser.parsePrice('\$1,299.99'), 1299.99);
      expect(ProductPageParser.parsePrice('29,90 €'), 29.9);
      expect(ProductPageParser.parsePrice('45.5'), 45.5);
    });

    test('rounds đồng', () {
      expect(
        ProductPageParser.parsePrice('499000.40', currency: 'vnd'),
        499000,
      );
    });

    test('drops missing, zero and out-of-range prices', () {
      expect(ProductPageParser.parsePrice(null), isNull);
      expect(ProductPageParser.parsePrice('Liên hệ'), isNull);
      expect(ProductPageParser.parsePrice('0'), isNull);
      expect(ProductPageParser.parsePrice('99.000.000'), isNull);
    });
  });
}
