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
  static const String _samba = '${idPrefix}samba';
  static const String _sharkHoodie = '${idPrefix}shark-hoodie';
  static const String _cargo = '${idPrefix}cargo-pants';
  static const String _carharttHoodie = '${idPrefix}carhartt-hoodie';
  static const String _stussyTee = '${idPrefix}stussy-long-sleeve';
  static const String _sherpaJacket = '${idPrefix}nuptse-jacket';
  static const String _balenciagaHoodie = '${idPrefix}balenciaga-hoodie';
  static const String _tripleS = '${idPrefix}triple-s';
  static const String _oldSkool = '${idPrefix}old-skool';
  static const String _chuck70 = '${idPrefix}chuck-70';
  static const String _dunkHigh = '${idPrefix}dunk-high';
  static const String _supremeAf1 = '${idPrefix}supreme-af1';
  static const String _jordanLow = '${idPrefix}jordan-1-low';

  static const String weekendDenimId = '${idPrefix}outfit-weekend-denim';
  static const String allBlackId = '${idPrefix}outfit-all-black';
  static const String offDutyId = '${idPrefix}outfit-off-duty';
  static const String hypeLayersId = '${idPrefix}outfit-hype-layers';
  static const String skateDayId = '${idPrefix}outfit-skate-day';

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
      // ponytail: fits 30 items; raise the base if the sample set grows.
      final created = now.subtract(Duration(days: 60 - order * 2));
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
        'Beige Trench Coat',
        ClothingCategory.outerwear,
        ClothingColor.beige,
        _transitional,
        brand: 'Vero Moda',
        price: 129,
      ),
      item(
        _slipDress,
        'Black Midi Dress',
        ClothingCategory.dresses,
        ClothingColor.black,
        _warm,
        brand: 'H&M',
        price: 39,
      ),
      item(
        _tote,
        'Pochette Métis Bag',
        ClothingCategory.bags,
        ClothingColor.brown,
        _allYear,
        brand: 'Louis Vuitton',
        price: 2570,
      ),
      item(
        _beigeChinos,
        'Beige Chinos',
        ClothingCategory.bottoms,
        ClothingColor.beige,
        _transitional,
        brand: 'Zara',
        price: 49,
      ),
      item(
        _blackCap,
        'Black 9FORTY Cap',
        ClothingCategory.accessories,
        ClothingColor.black,
        _allYear,
        brand: 'New Era',
        price: 30,
      ),
      item(
        _blackSneakers,
        'Black Court Sneakers',
        ClothingCategory.shoes,
        ClothingColor.black,
        _allYear,
        brand: 'Adidas',
        price: 75,
      ),
      item(
        _whiteSneakers,
        'Air Force 1',
        ClothingCategory.shoes,
        ClothingColor.white,
        _allYear,
        brand: 'Nike',
        price: 115,
        favorite: true,
        notes: 'Clean with a soft brush after rainy days.',
      ),
      item(
        _denimJacket,
        'Denim Jacket',
        ClothingCategory.outerwear,
        ClothingColor.blue,
        _transitional,
        brand: 'Lee',
        price: 98,
        favorite: true,
      ),
      item(
        _blackJeans,
        'Black Jeans',
        ClothingCategory.bottoms,
        ClothingColor.black,
        _allYear,
        brand: 'Acne Studios',
        price: 280,
      ),
      item(
        _blueJeans,
        'Blue Jeans',
        ClothingCategory.bottoms,
        ClothingColor.blue,
        _allYear,
        brand: 'Levi’s',
        price: 89,
        notes: 'Straight fit. Wash cold, inside out.',
      ),
      item(
        _blackTee,
        'Black Graphic Tee',
        ClothingCategory.tops,
        ClothingColor.black,
        _allYear,
        brand: 'H&M',
        price: 15,
      ),
      item(
        _whiteTee,
        'White T-Shirt',
        ClothingCategory.tops,
        ClothingColor.white,
        _allYear,
        brand: 'Uniqlo',
        price: 15,
        favorite: true,
      ),
      item(
        _samba,
        'Samba OG',
        ClothingCategory.shoes,
        ClothingColor.white,
        _allYear,
        brand: 'Adidas',
        price: 100,
      ),
      item(
        _sharkHoodie,
        'Shark Full Zip Hoodie',
        ClothingCategory.outerwear,
        ClothingColor.black,
        _cold,
        brand: 'BAPE',
        price: 435,
        favorite: true,
      ),
      item(
        _cargo,
        'Black Cargo Pants',
        ClothingCategory.bottoms,
        ClothingColor.black,
        _allYear,
        brand: 'Dickies',
        price: 65,
      ),
      item(
        _carharttHoodie,
        'Heart Patch Zip Hoodie',
        ClothingCategory.tops,
        ClothingColor.grey,
        _cold,
        brand: 'Carhartt WIP',
        price: 120,
      ),
      item(
        _stussyTee,
        'Stock Logo Long Sleeve',
        ClothingCategory.tops,
        ClothingColor.white,
        _transitional,
        brand: 'Stüssy',
        price: 55,
      ),
      item(
        _sherpaJacket,
        'Sherpa Fleece Jacket',
        ClothingCategory.outerwear,
        ClothingColor.beige,
        _cold,
        brand: 'The North Face',
        price: 330,
      ),
      item(
        _balenciagaHoodie,
        'Campaign Logo Hoodie',
        ClothingCategory.tops,
        ClothingColor.navy,
        _cold,
        brand: 'Balenciaga',
        price: 795,
      ),
      item(
        _tripleS,
        'Triple S',
        ClothingCategory.shoes,
        ClothingColor.white,
        _allYear,
        brand: 'Balenciaga',
        price: 1150,
      ),
      item(
        _oldSkool,
        'Old Skool',
        ClothingCategory.shoes,
        ClothingColor.black,
        _allYear,
        brand: 'Vans',
        price: 70,
        favorite: true,
      ),
      item(
        _chuck70,
        'Chuck 70 High',
        ClothingCategory.shoes,
        ClothingColor.black,
        _allYear,
        brand: 'Converse',
        price: 90,
      ),
      item(
        _dunkHigh,
        'Dunk High',
        ClothingCategory.shoes,
        ClothingColor.multi,
        _allYear,
        brand: 'Nike',
        price: 125,
      ),
      item(
        _supremeAf1,
        'Supreme Air Force 1',
        ClothingCategory.shoes,
        ClothingColor.white,
        _allYear,
        brand: 'Supreme',
        price: 150,
      ),
      item(
        _jordanLow,
        'Air Jordan 1 Low',
        ClothingCategory.shoes,
        ClothingColor.red,
        _allYear,
        brand: 'Jordan',
        price: 115,
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
      outfit(
        hypeLayersId,
        'Hype Layers',
        [_sharkHoodie, _blackTee, _cargo, _jordanLow, _blackCap],
        Occasion.casual,
        _cold,
        favorite: true,
        daysAgo: 5,
      ),
      outfit(
        skateDayId,
        'Skate Day',
        [_stussyTee, _blueJeans, _oldSkool],
        Occasion.casual,
        _transitional,
        daysAgo: 3,
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
