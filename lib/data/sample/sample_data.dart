import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/season.dart';

/// Development sample wardrobe. Every record id starts with [idPrefix], so it
/// can be removed cleanly from Settings → Remove sample data, and this whole
/// folder can be deleted without affecting user data.
abstract final class SampleData {
  static const String idPrefix = 'sample-';

  static bool isSampleId(String id) => id.startsWith(idPrefix);

  static const String _photoFolder = 'assets/sample';

  /// Sources and licenses of the bundled photos.
  static const String photoCreditsAsset = '$_photoFolder/CREDITS.txt';

  /// The bundled photo of a sample clothing item, or null for any other
  /// item. Used until the user gives the item a photo of their own.
  static String? photoFor(String itemId) => isSampleId(itemId)
      ? '$_photoFolder/${itemId.substring(idPrefix.length)}.jpg'
      : null;

  static const String _whiteTee = '${idPrefix}white-tee';
  static const String _blackTee = '${idPrefix}black-tee';
  static const String _blueJeans = '${idPrefix}blue-jeans';
  static const String _blackJeans = '${idPrefix}black-jeans';
  static const String _denimJacket = '${idPrefix}denim-jacket';
  static const String _whiteSneakers = '${idPrefix}white-sneakers';
  static const String _blackSneakers = '${idPrefix}black-sneakers';
  static const String _blackCap = '${idPrefix}black-cap';
  static const String _beigeChinos = '${idPrefix}beige-chinos';
  static const String _camelCoat = '${idPrefix}camel-coat';
  static const String _tote = '${idPrefix}leather-tote';
  static const String _slipDress = '${idPrefix}slip-dress';

  static const String weekendDenimId = '${idPrefix}outfit-weekend-denim';
  static const String allBlackId = '${idPrefix}outfit-all-black';
  static const String offDutyId = '${idPrefix}outfit-off-duty';

  static const List<Season> _allYear = Season.values;
  static const List<Season> _warm = [Season.spring, Season.summer];
  static const List<Season> _transitional = [Season.spring, Season.autumn];
  static const List<Season> _cold = [Season.autumn, Season.winter];

  static List<ClothingItem> items(DateTime now) {
    // Stagger creation dates so "recently added" and sorting look natural.
    var order = 0;
    ClothingItem item(
      String id,
      String name,
      ClothingCategory category,
      ClothingColor color,
      List<Season> seasons, {
      String? brand,
      double? price,
      String? notes,
      bool favorite = false,
    }) {
      final created = now.subtract(Duration(days: 40 - order * 3));
      order++;
      return ClothingItem(
        id: id,
        name: name,
        category: category,
        color: color,
        seasons: seasons,
        brand: brand,
        price: price,
        notes: notes,
        isFavorite: favorite,
        createdAt: created,
        updatedAt: created,
      );
    }

    return [
      item(
        _camelCoat,
        'Camel Wool Coat',
        ClothingCategory.outerwear,
        ClothingColor.beige,
        _cold,
        brand: 'Atelier Nine',
        price: 240,
      ),
      item(
        _slipDress,
        'Black Slip Dress',
        ClothingCategory.dresses,
        ClothingColor.black,
        _warm,
        brand: 'Maison Lune',
        price: 89,
      ),
      item(
        _tote,
        'Leather Tote',
        ClothingCategory.bags,
        ClothingColor.brown,
        _allYear,
        brand: 'Atelier Nine',
        price: 160,
      ),
      item(
        _beigeChinos,
        'Beige Chinos',
        ClothingCategory.bottoms,
        ClothingColor.beige,
        _transitional,
        brand: 'North Thread',
        price: 55,
      ),
      item(
        _blackCap,
        'Black Cap',
        ClothingCategory.accessories,
        ClothingColor.black,
        _allYear,
        brand: 'Everyday Co.',
        price: 25,
      ),
      item(
        _blackSneakers,
        'Black Sneakers',
        ClothingCategory.shoes,
        ClothingColor.black,
        _allYear,
        brand: 'Stride',
        price: 95,
      ),
      item(
        _whiteSneakers,
        'White Sneakers',
        ClothingCategory.shoes,
        ClothingColor.white,
        _allYear,
        brand: 'Stride',
        price: 110,
        favorite: true,
        notes: 'Clean with a soft brush after rainy days.',
      ),
      item(
        _denimJacket,
        'Denim Jacket',
        ClothingCategory.outerwear,
        ClothingColor.blue,
        _transitional,
        brand: 'North Thread',
        price: 98,
        favorite: true,
      ),
      item(
        _blackJeans,
        'Black Jeans',
        ClothingCategory.bottoms,
        ClothingColor.black,
        _allYear,
        brand: 'North Thread',
        price: 79,
      ),
      item(
        _blueJeans,
        'Blue Jeans',
        ClothingCategory.bottoms,
        ClothingColor.blue,
        _allYear,
        brand: 'North Thread',
        price: 69,
        notes: 'Straight fit. Wash cold, inside out.',
      ),
      item(
        _blackTee,
        'Black T-Shirt',
        ClothingCategory.tops,
        ClothingColor.black,
        _allYear,
        brand: 'Everyday Co.',
        price: 18,
      ),
      item(
        _whiteTee,
        'White T-Shirt',
        ClothingCategory.tops,
        ClothingColor.white,
        _allYear,
        brand: 'Everyday Co.',
        price: 18,
        favorite: true,
      ),
    ];
  }

  static List<Outfit> outfits(DateTime now) {
    Outfit outfit(
      String id,
      String name,
      List<String> itemIds,
      Occasion occasion,
      List<Season> seasons, {
      bool favorite = false,
      String? notes,
      int daysAgo = 0,
    }) {
      final created = now.subtract(Duration(days: daysAgo));
      return Outfit(
        id: id,
        name: name,
        itemIds: itemIds,
        occasion: occasion,
        seasons: seasons,
        notes: notes,
        isFavorite: favorite,
        createdAt: created,
        updatedAt: created,
      );
    }

    return [
      outfit(
        weekendDenimId,
        'Weekend Denim',
        [_denimJacket, _whiteTee, _blueJeans, _whiteSneakers, _blackCap],
        Occasion.casual,
        _transitional,
        favorite: true,
        notes: 'Roll the sleeves once.',
        daysAgo: 9,
      ),
      outfit(
        allBlackId,
        'All Black',
        [_blackTee, _blackJeans, _blackSneakers],
        Occasion.party,
        _allYear,
        daysAgo: 8,
      ),
      outfit(
        offDutyId,
        'Off-Duty Neutrals',
        [_camelCoat, _whiteTee, _beigeChinos, _whiteSneakers, _tote],
        Occasion.work,
        _cold,
        daysAgo: 7,
      ),
    ];
  }

  /// Past wears as (days ago, outfit id), applied through the normal
  /// wear-tracking flow so counts stay consistent.
  static const List<(int, String)> wearHistory = [
    (6, weekendDenimId),
    (4, allBlackId),
    (2, weekendDenimId),
    (1, offDutyId),
  ];

  /// Upcoming plans as (days from today, outfit id).
  static const List<(int, String)> plans = [
    (0, weekendDenimId),
    (2, allBlackId),
    (4, offDutyId),
  ];
}
