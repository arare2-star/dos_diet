import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/home_widget_service.dart';
import 'services/subscription_service.dart';
import 'screens/home_screen.dart';
import 'screens/food_log_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/imashime_report_screen.dart';
import 'widgets/mini_tanuki.dart';

/// 通知タップからの画面遷移用（通知はウィジェットツリーの外から来るため）
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 通知payloadを解釈して対応する画面を開く。
/// `imashime:<y>-<m>-<d>` → その日付の戒めレポート
void _handleNotificationPayload(StorageService storage, String payload) {
  final parts = payload.split(':');
  if (parts.length != 2 || parts[0] != 'imashime') return;
  final DateTime date;
  try {
    final ymd = parts[1].split('-').map(int.parse).toList();
    date = DateTime(ymd[0], ymd[1], ymd[2]);
  } catch (_) {
    return;
  }
  navigatorKey.currentState?.push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ImashimeReportScreen(
      storageService: storage,
      date: date,
    ),
  ));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('ja');
  await NotificationService.init();

  final storageService = StorageService();
  await storageService.init();

  // サブスクリプションサービスを初期化
  final subscriptionService = SubscriptionService();
  await subscriptionService.init();

  // アプリ起動時に現在の記録状態で通知とホームウィジェットを組み直す
  await NotificationService.reschedule(storageService);
  await HomeWidgetService.update(storageService);

  // 通知タップ→戒めレポート等の画面遷移
  NotificationService.onNotificationTap =
      (payload) => _handleNotificationPayload(storageService, payload);
  final launchPayload = await NotificationService.getLaunchPayload();

  runApp(DosDietApp(
    storageService: storageService,
    subscriptionService: subscriptionService,
  ));

  // 通知タップでアプリが起動された場合（コールドスタート）は初回フレーム後に開く
  if (launchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload(storageService, launchPayload);
    });
  }
}

class DosDietApp extends StatelessWidget {
  final StorageService storageService;
  final SubscriptionService subscriptionService;

  const DosDietApp({
    super.key,
    required this.storageService,
    required this.subscriptionService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dos Diet',
      navigatorKey: navigatorKey,
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      // 日本語ローカライズ設定
      // これがないとiOSのカメラUI・テキスト操作メニュー等が英語になる
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'), // フォールバック用
      ],
      locale: const Locale('ja', 'JP'),
      home: MainScreen(
        storageService: storageService,
        subscriptionService: subscriptionService,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final StorageService storageService;
  final SubscriptionService subscriptionService;

  const MainScreen({
    super.key,
    required this.storageService,
    required this.subscriptionService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<FoodLogScreenState> _foodLogKey = GlobalKey<FoodLogScreenState>();
  final GlobalKey<StatsScreenState> _statsKey = GlobalKey<StatsScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        key: _homeKey,
        storageService: widget.storageService,
        onAddFood: () => _switchTo(1),
      ),
      FoodLogScreen(
        key: _foodLogKey,
        storageService: widget.storageService,
        subscriptionService: widget.subscriptionService,
      ),
      StatsScreen(
        key: _statsKey,
        storageService: widget.storageService,
      ),
      SettingsScreen(
        storageService: widget.storageService,
        subscriptionService: widget.subscriptionService,
      ),
    ];

    // Request notification permissions on first launch
    Future.delayed(const Duration(seconds: 1), () {
      NotificationService.requestPermissions();
    });
  }

  void _switchTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _refreshCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 1:
        _foodLogKey.currentState?.refresh();
        break;
      case 2:
        _statsKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // 🦝 ドット絵ミニたぬき（最前面。本体以外はタッチ素通し）
          const Positioned.fill(child: MiniTanukiLayer()),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) {
              _refreshCurrentScreen();
            } else {
              setState(() => _currentIndex = index);
              // Refresh the new screen's data
              Future.microtask(_refreshCurrentScreen);
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'ホーム',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: '食事記録',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: '統計',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '設定',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton(
              onPressed: () {
                if (_currentIndex == 0) {
                  _switchTo(1);
                }
                _foodLogKey.currentState?.refresh();
              },
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }
}
