import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:placelist/models/category_model.dart';
import 'package:placelist/widgets/category_chip.dart';
import 'package:placelist/widgets/error_retry_widget.dart';
import 'package:placelist/widgets/plan/plan_header_widget.dart';
import 'package:placelist/widgets/shimmer_loading.dart';

void main() {
  group('PlanHeaderWidget Widget Tests', () {
    testWidgets('Renders title and triggers callbacks on button tap', (tester) async {
      bool refreshTapped = false;
      bool addPlanTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanHeaderWidget(
              isDark: false,
              onRefresh: () {
                refreshTapped = true;
              },
              onAddPlan: () {
                addPlanTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('내 일정'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      expect(refreshTapped, isTrue);

      await tester.tap(find.byIcon(Icons.add));
      expect(addPlanTapped, isTrue);
    });
  });

  group('ErrorRetryWidget Widget Tests', () {
    testWidgets('Renders error message and triggers onRetry callback', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorRetryWidget(
              message: '네트워크 연결 상태를 확인해주세요.',
              onRetry: () {
                retryTapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('데이터를 불러오지 못했습니다.'), findsOneWidget);
      expect(find.text('네트워크 연결 상태를 확인해주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      expect(retryTapped, isTrue);
    });
  });

  group('Shimmer Skeleton Widget Tests', () {
    testWidgets('StoreSkeletonCard renders without throwing exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StoreSkeletonCard(),
          ),
        ),
      );

      expect(find.byType(StoreSkeletonCard), findsOneWidget);
      expect(find.byType(ShimmerBox), findsWidgets);
    });

    testWidgets('PlanSkeletonCard renders without throwing exception', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlanSkeletonCard(),
          ),
        ),
      );

      expect(find.byType(PlanSkeletonCard), findsOneWidget);
      expect(find.byType(ShimmerBox), findsWidgets);
    });
  });

  group('CategoryChip Widget Tests', () {
    testWidgets('CategoryChip displays label and handles tap', (tester) async {
      const testCategory = Category(id: 'bakery', label: '베이커리', group: 'Style');

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CategoryChip(
                category: testCategory,
              ),
            ),
          ),
        ),
      );

      expect(find.text('베이커리'), findsOneWidget);

      await tester.tap(find.text('베이커리'));
      await tester.pumpAndSettle();
    });
  });
}
