import '../models/category_model.dart';
import '../DB/store.dart';

const List<Category> allCategories = [
  // Area
  Category(id: 'jeonpo', label: '전포', group: 'Area'),
  Category(id: 'gwangalli', label: '광안리', group: 'Area'),
  Category(id: 'haeundae', label: '해운대', group: 'Area'),

  // Food/Drink
  Category(id: 'coffee', label: '커피', group: 'Food/Drink'),
  Category(id: 'juice', label: '주스/스무디', group: 'Food/Drink'),
  Category(id: 'dessert', label: '디저트', group: 'Food/Drink'),
  Category(id: 'brunch', label: '브런치', group: 'Food/Drink'),

  // Concept/Style
  Category(id: 'europe', label: '유럽풍', group: 'Concept/Style'),
  Category(id: 'vintage', label: '빈티지', group: 'Concept/Style'),
  Category(id: 'garden', label: '정원', group: 'Concept/Style'),

  // View
  Category(id: 'ocean', label: '오션뷰', group: 'View'),
  Category(id: 'mountain', label: '마운틴뷰', group: 'View'),
  Category(id: 'rooftop', label: '루프탑', group: 'View'),

  // Type
  Category(id: 'franchise', label: '프랜차이즈', group: 'Type'),
  Category(id: 'independent', label: '개인', group: 'Type'),

  // Purpose
  Category(id: 'value', label: '가성비', group: 'Purpose'),
  Category(id: 'solo', label: '혼카페', group: 'Purpose'),
];

/// Groups categories by their group field.
Map<String, List<Category>> get categoriesByGroup {
  final map = <String, List<Category>>{};
  for (final cat in allCategories) {
    map.putIfAbsent(cat.group, () => []).add(cat);
  }
  return map;
}

List<Category> getStoreCategories(Store store) {
  final categories = <Category>[];
  final name = store.name;
  final folder = store.folderName.toLowerCase();
  final loc = store.location ?? '';

  Category? findCat(String id) {
    try {
      return allCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void addCat(String id) {
    final cat = findCat(id);
    if (cat != null) categories.add(cat);
  }

  // 1. Location / Area
  if (loc.contains('전포') || name.contains('전포')) {
    addCat('jeonpo');
  }
  if (loc.contains('광안') || name.contains('광안')) {
    addCat('gwangalli');
  }
  if (loc.contains('해운대') || loc.contains('해리단') || name.contains('해운대') || name.contains('해리단')) {
    addCat('haeundae');
  }

  // 2. Food/Drink
  // Coffee (커피)
  if (name.contains('커피') || name.contains('카페') || name.contains('에쏘') || name.contains('에스프레소') || name.contains('로스터리') || name.contains('스탠드') ||
      folder.contains('coffee') || folder.contains('espresso') || folder.contains('roastery') || folder.contains('esso')) {
    addCat('coffee');
  }
  // Juice (주스)
  if (name.contains('주스') || name.contains('스무디') || name.contains('에이드') || name.contains('티') ||
      folder.contains('juice') || folder.contains('tea')) {
    addCat('juice');
  }
  // Dessert
  if (name.contains('디저트') || name.contains('베이글') || name.contains('쿠키') || name.contains('도넛') || name.contains('케이크') || name.contains('베이커리') || name.contains('젤라또') || name.contains('에낭') || name.contains('타르트') || name.contains('크리머리') || name.contains('아틀리에') || name.contains('파이') ||
      folder.contains('bagel') || folder.contains('cookie') || folder.contains('donut') || folder.contains('bakery') || folder.contains('gelato') || folder.contains('creamery') || folder.contains('pie') || folder.contains('enang') || folder.contains('etalee')) {
    addCat('dessert');
  }
  // Brunch
  if (name.contains('브런치') || name.contains('샌드위치') || name.contains('바게트') || name.contains('오비아') || name.contains('써브즈') ||
      folder.contains('brunch') || folder.contains('ovia') || folder.contains('sseobeujeu') || folder.contains('bagel') || name.contains('베이글')) {
    addCat('brunch');
  }

  // 3. Concept/Style
  // Europe
  if (name.contains('유럽') || name.contains('프랑스') || name.contains('까사') || name.contains('부사노') || name.contains('오베르') || name.contains('덕미') || name.contains('라프') ||
      folder.contains('europe') || folder.contains('busano') || folder.contains('auvers') || folder.contains('deokmi') || folder.contains('laf')) {
    addCat('europe');
  }
  // Vintage
  if (name.contains('빈티지') || name.contains('구프') || name.contains('듀플릿') ||
      folder.contains('vintage') || folder.contains('goof') || folder.contains('duplit')) {
    addCat('vintage');
  }
  // Garden
  if (name.contains('정원') || name.contains('가든') || name.contains('식물') || name.contains('플라워') || name.contains('숲') ||
      folder.contains('garden')) {
    addCat('garden');
  }

  // 4. View
  // Ocean
  if (name.contains('오션') || name.contains('바다') || loc.contains('광안') || loc.contains('해운대') || name.contains('해운대') || name.contains('광안') ||
      folder.contains('ocean') || folder.contains('sea') || folder.contains('beach')) {
    addCat('ocean');
  }
  // Mountain
  if (name.contains('마운틴') || name.contains('산') || name.contains('산애') ||
      folder.contains('mountain') || folder.contains('sanae')) {
    addCat('mountain');
  }
  // Rooftop
  if (name.contains('루프탑') || name.contains('테라스') ||
      folder.contains('rooftop') || folder.contains('terrace')) {
    addCat('rooftop');
  }

  // 5. Type
  if (name.contains('점') || name.contains('프랜차이즈') || name.contains('올선데이') || name.contains('까사 부사노') || name.contains('듀플릿') || name.contains('로우앤스윗') || name.contains('스타벅스')) {
    addCat('franchise');
  } else {
    addCat('independent');
  }

  // 6. Purpose
  if (name.contains('가성비') || name.contains('싼') || name.contains('컴포즈') || name.contains('메가') || name.contains('빽다방')) {
    addCat('value');
  }
  if (name.contains('혼카페') || name.contains('공부') || name.contains('스터디') || name.contains('작업') || name.contains('이너프') || name.contains('구프') ||
      folder.contains('goof') || folder.contains('inouf')) {
    addCat('solo');
  }

  return categories;
}
