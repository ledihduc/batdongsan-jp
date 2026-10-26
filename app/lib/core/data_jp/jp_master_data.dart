/// JP market master data — prefectures, cities, property types, amenities, banks.
///
/// Used by jp-version branch to replace VN seeds when `FeatureFlags.isJapan`.
/// All labels are in Japanese; English/Vietnamese display is a translation layer concern.
library;

/// 47 都道府県 (prefectures). Code = ISO-3166-2:JP format (JP-XX).
class JpPrefecture {
  const JpPrefecture(this.code, this.name, this.region);
  final String code; // 'JP-13'
  final String name; // '東京都'
  final String region; // '関東'
}

const jpPrefectures = <JpPrefecture>[
  JpPrefecture('JP-01', '北海道', '北海道'),
  JpPrefecture('JP-02', '青森県', '東北'),
  JpPrefecture('JP-03', '岩手県', '東北'),
  JpPrefecture('JP-04', '宮城県', '東北'),
  JpPrefecture('JP-05', '秋田県', '東北'),
  JpPrefecture('JP-06', '山形県', '東北'),
  JpPrefecture('JP-07', '福島県', '東北'),
  JpPrefecture('JP-08', '茨城県', '関東'),
  JpPrefecture('JP-09', '栃木県', '関東'),
  JpPrefecture('JP-10', '群馬県', '関東'),
  JpPrefecture('JP-11', '埼玉県', '関東'),
  JpPrefecture('JP-12', '千葉県', '関東'),
  JpPrefecture('JP-13', '東京都', '関東'),
  JpPrefecture('JP-14', '神奈川県', '関東'),
  JpPrefecture('JP-15', '新潟県', '中部'),
  JpPrefecture('JP-16', '富山県', '中部'),
  JpPrefecture('JP-17', '石川県', '中部'),
  JpPrefecture('JP-18', '福井県', '中部'),
  JpPrefecture('JP-19', '山梨県', '中部'),
  JpPrefecture('JP-20', '長野県', '中部'),
  JpPrefecture('JP-21', '岐阜県', '中部'),
  JpPrefecture('JP-22', '静岡県', '中部'),
  JpPrefecture('JP-23', '愛知県', '中部'),
  JpPrefecture('JP-24', '三重県', '近畿'),
  JpPrefecture('JP-25', '滋賀県', '近畿'),
  JpPrefecture('JP-26', '京都府', '近畿'),
  JpPrefecture('JP-27', '大阪府', '近畿'),
  JpPrefecture('JP-28', '兵庫県', '近畿'),
  JpPrefecture('JP-29', '奈良県', '近畿'),
  JpPrefecture('JP-30', '和歌山県', '近畿'),
  JpPrefecture('JP-31', '鳥取県', '中国'),
  JpPrefecture('JP-32', '島根県', '中国'),
  JpPrefecture('JP-33', '岡山県', '中国'),
  JpPrefecture('JP-34', '広島県', '中国'),
  JpPrefecture('JP-35', '山口県', '中国'),
  JpPrefecture('JP-36', '徳島県', '四国'),
  JpPrefecture('JP-37', '香川県', '四国'),
  JpPrefecture('JP-38', '愛媛県', '四国'),
  JpPrefecture('JP-39', '高知県', '四国'),
  JpPrefecture('JP-40', '福岡県', '九州'),
  JpPrefecture('JP-41', '佐賀県', '九州'),
  JpPrefecture('JP-42', '長崎県', '九州'),
  JpPrefecture('JP-43', '熊本県', '九州'),
  JpPrefecture('JP-44', '大分県', '九州'),
  JpPrefecture('JP-45', '宮崎県', '九州'),
  JpPrefecture('JP-46', '鹿児島県', '九州'),
  JpPrefecture('JP-47', '沖縄県', '沖縄'),
];

/// 23 wards of Tokyo (特別区) — most relevant for JP launch (metro Tokyo focus).
const jpTokyoWards = <String>[
  '千代田区', '中央区', '港区', '新宿区', '文京区', '台東区', '墨田区', '江東区',
  '品川区', '目黒区', '大田区', '世田谷区', '渋谷区', '中野区', '杉並区', '豊島区',
  '北区', '荒川区', '板橋区', '練馬区', '足立区', '葛飾区', '江戸川区',
];

/// Osaka 24 wards.
const jpOsakaWards = <String>[
  '北区', '都島区', '福島区', '此花区', '中央区', '西区', '港区', '大正区',
  '天王寺区', '浪速区', '西淀川区', '東淀川区', '東成区', '生野区', '旭区',
  '城東区', '阿倍野区', '住吉区', '東住吉区', '西成区', '淀川区', '鶴見区',
  '住之江区', '平野区',
];

/// 物件種別 — property types used in chintai (rental) search facets.
class JpPropertyType {
  const JpPropertyType(this.code, this.label);
  final String code;
  final String label;
}

const jpPropertyTypes = <JpPropertyType>[
  JpPropertyType('mansion', 'マンション'),
  JpPropertyType('apartment', 'アパート'),
  JpPropertyType('detached', '一戸建て'),
  JpPropertyType('terrace', 'テラスハウス'),
  JpPropertyType('share', 'シェアハウス'),
  JpPropertyType('serviced', 'サービスアパートメント'),
  JpPropertyType('store', '店舗'),
  JpPropertyType('office', '事務所'),
];

/// 間取り — Japanese room layouts (LDK format).
const jpLayouts = <String>[
  '1R', '1K', '1DK', '1LDK',
  '2K', '2DK', '2LDK',
  '3K', '3DK', '3LDK',
  '4LDK', '5LDK以上',
];

/// 設備・条件 — amenities / conditions commonly listed on Japanese rental sites.
class JpAmenity {
  const JpAmenity(this.code, this.label);
  final String code;
  final String label;
}

const jpAmenities = <JpAmenity>[
  JpAmenity('air_conditioner', 'エアコン'),
  JpAmenity('washing_machine_in', '室内洗濯機置場'),
  JpAmenity('bath_toilet_separate', 'バス・トイレ別'),
  JpAmenity('reheating', '追い焚き'),
  JpAmenity('auto_lock', 'オートロック'),
  JpAmenity('delivery_box', '宅配ボックス'),
  JpAmenity('elevator', 'エレベーター'),
  JpAmenity('parking', '駐車場'),
  JpAmenity('bicycle_parking', '駐輪場'),
  JpAmenity('pet_allowed', 'ペット相談'),
  JpAmenity('instrument_allowed', '楽器相談'),
  JpAmenity('furnished', '家具・家電付'),
  JpAmenity('internet_free', 'インターネット無料'),
  JpAmenity('city_gas', '都市ガス'),
  JpAmenity('system_kitchen', 'システムキッチン'),
  JpAmenity('ih_cooker', 'IHクッキングヒーター'),
  JpAmenity('two_sided_lighting', '二面採光'),
  JpAmenity('south_facing', '南向き'),
  JpAmenity('corner_room', '角部屋'),
  JpAmenity('top_floor', '最上階'),
  JpAmenity('new_build', '新築'),
  JpAmenity('renovated', 'リフォーム済'),
  JpAmenity('separate_toilet', 'トイレ別'),
  JpAmenity('tv_intercom', 'TVモニタホン'),
];

/// 契約条件 — contract conditions / fees.
const jpContractTerms = <String, String>{
  'rent': '家賃',
  'management_fee': '管理費',
  'deposit': '敷金',
  'key_money': '礼金',
  'guarantee_fee': '保証料',
  'agency_fee': '仲介手数料',
  'contract_period': '契約期間',
  'renewal_fee': '更新料',
  'insurance': '火災保険',
  'key_exchange': '鍵交換費用',
};

/// Top 10 Japanese banks (used for payout settlement destinations).
class JpBank {
  const JpBank(this.code, this.name);
  final String code; // zengin bank code (4 digits)
  final String name;
}

const jpBanks = <JpBank>[
  JpBank('0001', 'みずほ銀行'),
  JpBank('0005', '三菱UFJ銀行'),
  JpBank('0009', '三井住友銀行'),
  JpBank('0010', 'りそな銀行'),
  JpBank('0017', '埼玉りそな銀行'),
  JpBank('0033', 'PayPay銀行'),
  JpBank('0034', 'セブン銀行'),
  JpBank('0035', 'ソニー銀行'),
  JpBank('0036', '楽天銀行'),
  JpBank('0038', '住信SBIネット銀行'),
  JpBank('0310', 'GMOあおぞらネット銀行'),
  JpBank('0397', '新生銀行'),
  JpBank('0398', 'あおぞら銀行'),
  JpBank('9900', 'ゆうちょ銀行'),
];
