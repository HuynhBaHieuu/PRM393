import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';

/// What a shop's product page says about the piece. Every field is
/// optional: pages rarely carry all of them.
class ProductPage {
  const ProductPage({
    required this.url,
    this.name,
    this.brand,
    this.price,
    this.currency,
    this.imageUrl,
  });

  final Uri url;
  final String? name;
  final String? brand;
  final double? price;

  /// ISO code such as "VND" or "USD", when the page gives one.
  final String? currency;
  final Uri? imageUrl;

  bool get isEmpty =>
      name == null && brand == null && price == null && imageUrl == null;
}

/// A [ProductPage] whose photo has been downloaded to [imagePath], a
/// temporary file the clothing form imports like a picked photo.
class ProductLinkResult {
  const ProductLinkResult({required this.page, this.imagePath});

  final ProductPage page;
  final String? imagePath;
}

abstract interface class ProductLinkService {
  /// Reads the product page at [link]. Throws [ProductLinkException] when
  /// the link is not a web address or the page can't be read.
  Future<ProductLinkResult> fetch(String link);
}

/// Loads the page straight from the shop, as a browser would, and reads
/// the details shops publish for link previews and search engines:
/// schema.org Product data (JSON-LD) first, then Open Graph and product
/// meta tags, then the page title.
///
/// Pages that build themselves with JavaScript, or that block apps, give
/// little or nothing; the form then keeps what was found and the user
/// fills in the rest.
class WebProductLinkService implements ProductLinkService {
  const WebProductLinkService();

  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxPageBytes = 4 * 1024 * 1024;
  static const int _maxImageBytes = 15 * 1024 * 1024;

  // A desktop browser's agent: many shops serve bots and apps an empty
  // shell, but browsers the full page with its preview tags.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  static const Map<String, String> _imageExtensions = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
  };

  @override
  Future<ProductLinkResult> fetch(String link) async {
    final url = ProductPageParser.findUrl(link);
    if (url == null) {
      throw const ProductLinkException(
        'That doesn’t look like a link. Copy the product’s web address.',
      );
    }
    final client = HttpClient()..userAgent = _userAgent;
    try {
      final (html, finalUrl) = await _getPage(client, url);
      final page = ProductPageParser.parse(html, finalUrl);
      // Shops behind bot protection (Zara, Shopee…) answer apps with a
      // placeholder page that has no details, rather than an error.
      if (page.isEmpty) {
        throw const ProductLinkException(
          'This shop doesn’t share product details with apps; it only shows '
          'them in a web browser. Save the product photo and add it from '
          'your gallery instead.',
        );
      }
      final imageUrl = page.imageUrl;
      final imagePath = imageUrl == null
          ? null
          : await _downloadImage(client, imageUrl, referer: finalUrl);
      return ProductLinkResult(page: page, imagePath: imagePath);
    } finally {
      client.close(force: true);
    }
  }

  Future<(String, Uri)> _getPage(HttpClient client, Uri url) async {
    try {
      final request = await client.getUrl(url).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'text/html,application/xhtml+xml')
        ..set(HttpHeaders.acceptLanguageHeader, 'vi-VN,vi;q=0.9,en;q=0.8');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw ProductLinkException(switch (response.statusCode) {
          // Bot protection (Cloudflare, Akamai…) answers apps this way.
          HttpStatus.forbidden ||
          HttpStatus.tooManyRequests ||
          HttpStatus.serviceUnavailable =>
            'This shop only opens its pages in a web browser, so the app '
                'can’t read them. Save the product photo and add it from '
                'your gallery instead.',
          HttpStatus.notFound => 'This product page no longer exists.',
          final code => 'The shop didn’t open this page (error $code).',
        });
      }
      final bytes = await _readCapped(response, _maxPageBytes);
      final finalUrl = response.redirects.isEmpty
          ? url
          : url.resolveUri(response.redirects.last.location);
      return (utf8.decode(bytes, allowMalformed: true), finalUrl);
    } on ProductLinkException {
      rethrow;
    } catch (_) {
      throw const ProductLinkException(
        'The page could not be loaded. Check your connection and the link.',
      );
    }
  }

  /// Returns null when the photo can't be used; the details still are.
  Future<String?> _downloadImage(
    HttpClient client,
    Uri url, {
    required Uri referer,
  }) async {
    try {
      final request = await client.getUrl(url).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'image/webp,image/jpeg,image/png,*/*')
        ..set(HttpHeaders.refererHeader, referer.toString());
      final response = await request.close().timeout(_timeout);
      final type = response.headers.contentType?.mimeType.toLowerCase();
      final extension = _imageExtensions[type];
      if (response.statusCode != HttpStatus.ok || extension == null) {
        await response.drain<void>();
        return null;
      }
      final bytes = await _readCapped(response, _maxImageBytes);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/link_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>> _readCapped(Stream<List<int>> stream, int max) {
    final builder = BytesBuilder(copy: false);
    final done = Completer<List<int>>();
    late final StreamSubscription<List<int>> subscription;
    subscription = stream
        .timeout(_timeout)
        .listen(
          (chunk) {
            builder.add(chunk);
            // Enough for every tag we read; the rest of a huge page is skipped.
            if (builder.length >= max) {
              subscription.cancel();
              done.complete(builder.takeBytes());
            }
          },
          onError: (Object error) {
            if (!done.isCompleted) done.completeError(error);
          },
          onDone: () {
            if (!done.isCompleted) done.complete(builder.takeBytes());
          },
          cancelOnError: true,
        );
    return done.future;
  }
}

/// Pure parsing, kept apart from the network so it can be tested.
abstract final class ProductPageParser {
  static final RegExp _urlPattern = RegExp(r'https?://[^\s<>"]+');
  static final RegExp _bareDomain = RegExp(
    r'^[a-z0-9-]+(\.[a-z0-9-]+)+(/\S*)?$',
    caseSensitive: false,
  );
  static final RegExp _metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
  static final RegExp _attribute = RegExp(
    r'''([a-zA-Z_:.-]+)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))''',
  );
  static final RegExp _jsonLd = RegExp(
    r'''<script\b[^>]*type\s*=\s*["']?application/ld\+json["']?[^>]*>([\s\S]*?)</script>''',
    caseSensitive: false,
  );
  static final RegExp _title = RegExp(
    r'<title\b[^>]*>([\s\S]*?)</title>',
    caseSensitive: false,
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Marketplaces sell many brands, so their site name is not the brand.
  static const Set<String> _marketplaces = {
    'shopee',
    'lazada',
    'tiki',
    'sendo',
    'tiktok',
    'amazon',
    'ebay',
    'etsy',
    'aliexpress',
    'taobao',
    'shein',
    'temu',
    'zalando',
    'asos',
    'facebook',
    'instagram',
  };

  /// The first web address in [text], which may be a whole share message
  /// such as "Look at this! https://s.shopee.vn/abc". A bare
  /// "zara.com/..." gets https.
  static Uri? findUrl(String text) {
    final trimmed = text.trim();
    final match = _urlPattern.firstMatch(trimmed)?.group(0);
    final candidate =
        match ?? (_bareDomain.hasMatch(trimmed) ? 'https://$trimmed' : null);
    if (candidate == null) return null;
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    return uri;
  }

  static ProductPage parse(String html, Uri pageUrl) {
    final meta = _readMeta(html);
    final product = _findJsonLdProduct(html);
    final offer = product == null ? null : _offerOf(product);

    final siteName = _clean(meta['og:site_name']);
    final rawName =
        _text(product?['name']) ??
        _clean(meta['og:title']) ??
        _clean(meta['twitter:title']) ??
        _clean(_title.firstMatch(html)?.group(1));

    final currency =
        _text(offer?['priceCurrency']) ??
        _clean(meta['product:price:currency']) ??
        _clean(meta['og:price:currency']) ??
        _clean(meta['pricecurrency']);
    final priceText =
        _text(offer?['price']) ??
        _text(offer?['lowPrice']) ??
        _clean(meta['product:price:amount']) ??
        _clean(meta['og:price:amount']) ??
        _clean(meta['price']);

    final brand =
        _brandName(product?['brand']) ??
        _clean(meta['product:brand']) ??
        _clean(meta['og:brand']) ??
        _clean(meta['brand']) ??
        (siteName != null && !_isMarketplace(pageUrl, siteName)
            ? siteName
            : null);

    final image =
        _imageUrl(product?['image']) ??
        _clean(meta['og:image:secure_url']) ??
        _clean(meta['og:image']) ??
        _clean(meta['twitter:image']) ??
        _clean(meta['image']);

    return ProductPage(
      url: pageUrl,
      name: _shortName(rawName, siteName: siteName, host: pageUrl.host),
      brand: brand == null ? null : _limit(brand, Validators.maxNameLength),
      price: parsePrice(priceText, currency: currency),
      currency: currency?.toUpperCase(),
      imageUrl: _resolve(pageUrl, image),
    );
  }

  /// Reads "499000", "499.000", "499.000 ₫", "1,299.99" or "29,90 €".
  /// Dots grouping thousands (common in VND) are told apart from decimal
  /// points by the three digits after each. Prices over the app's limit
  /// are dropped rather than saved wrong.
  static double? parsePrice(String? text, {String? currency}) {
    if (text == null) return null;
    var digits = text.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (digits.isEmpty) return null;
    final thousandsDots = RegExp(r'^\d{1,3}(\.\d{3})+(,\d{1,2})?$');
    final thousandsCommas = RegExp(r'^\d{1,3}(,\d{3})+(\.\d{1,2})?$');
    if (thousandsDots.hasMatch(digits)) {
      digits = digits.replaceAll('.', '').replaceAll(',', '.');
    } else if (thousandsCommas.hasMatch(digits)) {
      digits = digits.replaceAll(',', '');
    } else if (digits.contains(',') && !digits.contains('.')) {
      digits = digits.replaceAll(',', '.');
    } else {
      digits = digits.replaceAll(',', '');
    }
    final value = double.tryParse(digits);
    if (value == null || !value.isFinite || value <= 0) return null;
    if (value > Validators.maxPrice) return null;
    // Đồng have no cents; a "499000.00" page still means 499 000.
    return currency?.toUpperCase() == 'VND' ? value.roundToDouble() : value;
  }

  /// Content of `<meta>` tags by lower-cased property, name or itemprop.
  /// The first tag with a key wins.
  static Map<String, String> _readMeta(String html) {
    final found = <String, String>{};
    for (final tag in _metaTag.allMatches(html)) {
      final attributes = <String, String>{};
      for (final a in _attribute.allMatches(tag.group(0)!)) {
        attributes[a.group(1)!.toLowerCase()] =
            a.group(3) ?? a.group(4) ?? a.group(5) ?? '';
      }
      final key =
          attributes['property'] ??
          attributes['name'] ??
          attributes['itemprop'];
      final content = attributes['content'];
      if (key == null || content == null || content.trim().isEmpty) continue;
      found.putIfAbsent(key.toLowerCase(), () => content);
    }
    return found;
  }

  static Map<String, dynamic>? _findJsonLdProduct(String html) {
    for (final block in _jsonLd.allMatches(html)) {
      try {
        final product = _productIn(jsonDecode(block.group(1)!.trim()));
        if (product != null) return product;
      } on FormatException {
        // Shops sometimes ship broken JSON-LD; the meta tags remain.
      }
    }
    return null;
  }

  static Map<String, dynamic>? _productIn(Object? node) {
    if (node is List) {
      for (final child in node) {
        final product = _productIn(child);
        if (product != null) return product;
      }
    } else if (node is Map) {
      final map = Map<String, dynamic>.from(node);
      final type = map['@type'];
      final types = type is List ? type : [type];
      bool isProduct(Object? t) {
        final name = '$t'.toLowerCase();
        return name.endsWith('product') || name.endsWith('productgroup');
      }

      if (types.any(isProduct)) {
        return map;
      }
      return _productIn(map['@graph']) ??
          _productIn(map['mainEntity']) ??
          _productIn(map['itemListElement']);
    }
    return null;
  }

  /// A ProductGroup prices its variants (sizes, colors), not itself.
  static Map<String, dynamic>? _offerOf(Map<String, dynamic> product) {
    final own = _firstOffer(product['offers']);
    if (own != null) return own;
    final variants = product['hasVariant'];
    for (final variant in variants is List ? variants : [variants]) {
      if (variant is! Map) continue;
      final offer = _firstOffer(variant['offers']);
      if (offer != null) return offer;
    }
    return null;
  }

  static Map<String, dynamic>? _firstOffer(Object? offers) {
    if (offers is List) {
      return offers.isEmpty ? null : _firstOffer(offers.first);
    }
    if (offers is! Map) return null;
    final map = Map<String, dynamic>.from(offers);
    // An AggregateOffer may nest the real offers.
    if (map['price'] == null && map['lowPrice'] == null) {
      return _firstOffer(map['offers']) ?? map;
    }
    return map;
  }

  static String? _brandName(Object? brand) {
    if (brand is List) return brand.isEmpty ? null : _brandName(brand.first);
    if (brand is Map) return _text(brand['name']);
    return _text(brand);
  }

  static String? _imageUrl(Object? image) {
    if (image is List) return image.isEmpty ? null : _imageUrl(image.first);
    if (image is Map) return _text(image['url'] ?? image['contentUrl']);
    return _text(image);
  }

  static Uri? _resolve(Uri page, String? link) {
    if (link == null) return null;
    final uri = Uri.tryParse(link.startsWith('//') ? 'https:$link' : link);
    if (uri == null) return null;
    final resolved = page.resolveUri(uri);
    // Android refuses plain http, and shops serve their images over both.
    if (resolved.isScheme('http')) return resolved.replace(scheme: 'https');
    return resolved.isScheme('https') ? resolved : null;
  }

  static bool _isMarketplace(Uri page, String siteName) {
    final words = '${page.host} $siteName'.toLowerCase();
    return _marketplaces.any(words.contains);
  }

  /// Drops a " | Shopee Việt Nam"-style suffix naming the site, then keeps
  /// the name within the form's limit.
  static String? _shortName(
    String? name, {
    required String? siteName,
    required String host,
  }) {
    if (name == null) return null;
    var result = name;
    final siteWords = {
      ?siteName?.toLowerCase(),
      ...host.toLowerCase().split('.').where((p) => p.length > 3),
      ..._marketplaces,
    };
    for (final separator in [' | ', ' - ', ' – ', ' — ']) {
      final at = result.lastIndexOf(separator);
      if (at <= 0) continue;
      final suffix = result.substring(at + separator.length).toLowerCase();
      if (siteWords.any((w) => w.isNotEmpty && suffix.contains(w))) {
        result = result.substring(0, at).trim();
      }
    }
    return result.isEmpty ? null : _limit(result, Validators.maxItemNameLength);
  }

  static String _limit(String text, int max) {
    if (text.length <= max) return text;
    final cut = text.substring(0, max);
    final space = cut.lastIndexOf(' ');
    return (space > max ~/ 2 ? cut.substring(0, space) : cut).trim();
  }

  static String? _text(Object? value) =>
      value is String || value is num ? _clean('$value') : null;

  static String? _clean(String? value) {
    if (value == null) return null;
    final text = _decodeEntities(value).replaceAll(_whitespace, ' ').trim();
    return text.isEmpty ? null : text;
  }

  static final RegExp _entity = RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);');
  static const Map<String, String> _namedEntities = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
  };

  static String _decodeEntities(String text) =>
      text.replaceAllMapped(_entity, (m) {
        final code = m.group(1)!;
        if (code.startsWith('#')) {
          final hex = code.startsWith('#x') || code.startsWith('#X');
          final value = int.tryParse(
            code.substring(hex ? 2 : 1),
            radix: hex ? 16 : 10,
          );
          return value == null ? m.group(0)! : String.fromCharCode(value);
        }
        return _namedEntities[code.toLowerCase()] ?? m.group(0)!;
      });
}
