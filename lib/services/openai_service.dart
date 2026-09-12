import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// カロリー推定サービス。クラス名は歴史的経緯でOpenAIServiceのままだが、
/// 2026-09-12からモデルはClaude Sonnet 5（Anthropic API）を使っている。
/// 比較は tools/scan_test.py で実施（gpt-4o比で外食の過小評価が改善、約1円/5秒）。
class OpenAIService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-5';

  static String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  /// 構造化出力のスキーマ（_prompt内のJSON例と同じ形）。これでJSON以外が混ざらない
  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'food_name': {'type': 'string'},
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'amount': {'type': 'string'},
            'calories': {'type': 'integer'},
          },
          'required': ['name', 'amount', 'calories'],
          'additionalProperties': false,
        },
      },
      'calories': {'type': 'integer'},
      'description': {'type': 'string'},
      'confidence': {'type': 'string', 'enum': ['high', 'medium', 'low']},
    },
    'required': ['food_name', 'items', 'calories', 'description', 'confidence'],
    'additionalProperties': false,
  };

  /// 品目ごとに分量→kcalを出させて合算する方式。一塊で推定させるより誤差が小さい。
  /// 皿・茶碗・箸などを基準物にして分量を見積もらせる。
  static const String _prompt = '''あなたは管理栄養士です。この食事の写真からカロリーを推定してください。

手順:
1. 写真に写っている料理・食品を1品ずつ分けて挙げる（定食なら白米・味噌汁・主菜・小鉢を別々に）
2. 各品目の分量(g または ml)を推定する。皿・茶碗・箸・スプーン・手・缶やペットボトルなど、写っている物の大きさを基準にして見積もること
3. 各品目の分量からカロリーを計算する（一般的な日本の食品成分値に基づく）
4. 合計を出す

注意（過小評価を防ぐため）:
- 外食・定食チェーン・コンビニの料理は家庭料理より分量が多く油も多い。外食と思われる写真は多めに見積もる
- 揚げ物は衣が油を吸うため重量あたりのカロリーが高い（とんかつ・唐揚げ・チキン南蛮・天ぷらは100gあたり250〜300kcal）
- タルタルソース・マヨネーズ・ドレッシング・甘酢だれ・カレールー・バターなどソース/油脂類は、かかっている量を見積もって必ず別品目として計上する（タルタル大さじ1杯≒100kcal）
- 分量に迷ったら少なめでなく多めに見積もる。ダイエット用途なので過小評価の方が有害

以下のJSONのみを返してください。説明文は不要です。
{
  "food_name": "食事全体の名前（日本語、短く。例: 鮭の塩焼き定食）",
  "items": [
    {"name": "品目名（日本語）", "amount": "分量（例: 200g, 180ml, 1個）", "calories": 整数kcal}
  ],
  "calories": 合計の整数kcal,
  "description": "料理の簡単な説明（日本語、1文。分量やカロリーの根拠は書かない）",
  "confidence": "high/medium/low"
}''';

  /// APIレスポンスのJSONをCalorieResultにする。品目があれば合計は品目の和を優先する
  static CalorieResult parseResult(Map<String, dynamic> parsed) {
    final items = ((parsed['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => FoodItem(
              name: (e['name'] ?? '').toString(),
              amount: (e['amount'] ?? '').toString(),
              calories: (e['calories'] as num?)?.toInt() ?? 0,
            ))
        .where((e) => e.name.isNotEmpty)
        .toList();
    final total = items.isNotEmpty
        ? items.fold<int>(0, (sum, e) => sum + e.calories)
        : (parsed['calories'] as num?)?.toInt() ?? 0;
    return CalorieResult(
      foodName: parsed['food_name'] ?? '不明な食べ物',
      calories: _dejitterRound(total),
      description: parsed['description'] ?? '',
      confidence: parsed['confidence'] ?? 'low',
      items: items,
    );
  }

  /// 画像からカロリーを推測する
  static Future<CalorieResult> estimateCaloriesFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 4000,
        'output_config': {
          'format': {'type': 'json_schema', 'schema': _schema},
        },
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {'type': 'text', 'text': _prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['stop_reason'] == 'refusal') {
        throw Exception('この画像は解析できませんでした');
      }
      final content = (data['content'] as List)
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'] as String)
          .join();

      // JSONを抽出してパース
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        return parseResult(jsonDecode(jsonMatch.group(0)!));
      }
    }

    throw Exception('カロリー推定に失敗しました (${response.statusCode})');
  }

  /// AIの推定値はほぼ必ずキリのいい数字（10・50の倍数）で返ってくるため、
  /// 一桁台にゆらぎを入れて実測っぽい粒度にする（もともと±20%程度の概算なので精度は落ちない）。
  /// これでスロット演出のゾロ目・777がスキャン経由でも現実的に出るようになる
  static int _dejitterRound(int calories) {
    if (calories < 30 || calories % 5 != 0) return calories; // 元から端数ならそのまま
    final jittered = calories + Random().nextInt(15) - 7; // ±7
    return jittered < 1 ? calories : jittered;
  }

  /// 食事タイプの日本語ラベルを返す
  static String getMealLabel(String type) {
    switch (type) {
      case 'breakfast': return '朝食';
      case 'lunch':     return '昼食';
      case 'dinner':    return '夕食';
      case 'snack':     return 'おやつ';
      default:          return '食事';
    }
  }

  /// ぽんぽこコーチからのフィードバックを生成（1食 vs 食事別目標）
  static PontaFeedback getPontaFeedback(int mealCalories, int mealGoal, String mealType) {
    final label = getMealLabel(mealType);
    final over = mealCalories - mealGoal;
    final under = mealGoal - mealCalories;
    final ratio = mealCalories / mealGoal;

    // ランダム性を出すためにカロリーの下一桁で分岐
    final v = mealCalories % 3;

    if (ratio >= 2.0) {
      // 目標の2倍以上：草不可避レベル
      final msgs = [
        '${label}で${mealCalories}kcalwwwww\n絶対痩せる気ないぽんwww目標の2倍って何食ったんぽんwww',
        '${mealCalories}kcalは草ぽんwwwww\nもうダイエットやめたほうが早いんじゃないかぽん？？www',
        'え待って${mealCalories}kcalってマジぽん？wwww\n${over}kcalオーバーって清々しいくらい振り切れてるぽんwww',
      ];
      return PontaFeedback(message: msgs[v]);

    } else if (ratio >= 1.5) {
      // 目標の1.5倍以上：激怒
      final msgs = [
        'はあ？${label}で${mealCalories}kcalって正気ぽん？w\n目標${mealGoal}kcalを${over}kcalもオーバーしてて笑えないぽん。',
        '${over}kcalオーバーwww\nぽんぽこ引いてるぽん…本当に痩せたいんかぽん？',
        'そのカロリー見て何も思わないぽん？w\n${label}${mealCalories}kcalはちょっとありえないぽん。反省するぽん。',
      ];
      return PontaFeedback(message: msgs[v]);

    } else if (ratio >= 1.2) {
      // 目標の1.2〜1.5倍：呆れ気味
      final msgs = [
        '${label}またオーバーしてるじゃないかぽんw\n${over}kcal多いぽん。まあ…想定内だけどさぽん。',
        'うーん${mealCalories}kcalかぽん…\n目標より${over}kcalはみ出てるぽん。惜しいような惜しくないようなw',
        'オーバーは×ぽん。でも${over}kcalくらいなら\n明日ちゃんとやれば帳消しにできるぽん。やれよぽんw',
      ];
      return PontaFeedback(message: msgs[v]);

    } else if (ratio > 1.0) {
      // 目標をちょいオーバー：ため息系
      final msgs = [
        'あとちょっとだったぽんw\n${over}kcalはみ出てるぽん。詰めが甘いんだよなぽん。',
        'ギリアウトぽん…w\nあと${over}kcal我慢できなかったぽん？惜しすぎるぽん。',
        'もうちょいだったのに〜ぽんw\n${over}kcalオーバー。次は絶対収めるぽん、いいかぽん？',
      ];
      return PontaFeedback(message: msgs[v]);

    } else if (ratio >= 0.8) {
      // 目標の8〜10割：合格
      final msgs = [
        '${label}は合格ぽん👏\nちゃんと目標以内に収まったぽん。えらいじゃないかぽん。',
        'おっ、ちゃんとやるじゃないかぽん。\n${label}${mealCalories}kcal、合格ぽん！この調子ぽん。',
        '悪くないぽん。\n目標${mealGoal}kcalに対して${mealCalories}kcalはセーフぽん。毎回これでいくぽん。',
      ];
      return PontaFeedback(message: msgs[v]);

    } else if (ratio >= 0.5) {
      // 目標の5〜8割：褒め
      final msgs = [
        'おお、${label}余裕で収まったぽん！🎉\n目標より${under}kcal少ないぽん。やればできるじゃないかぽん！',
        '${mealCalories}kcalはなかなかいいぽん！\nこれを毎回続けるぽん。逃げんなよぽんw',
        'いいじゃないかぽん〜！\n${label}${under}kcalも余ったぽん。ぽんぽこ的に合格以上ぽん👍',
      ];
      return PontaFeedback(message: msgs[v]);

    } else {
      // 目標の半分以下：少なすぎ注意
      final msgs = [
        '${label}${mealCalories}kcalって少なすぎぽん…\nダイエットは飢えればいいってもんじゃないぽん。ちゃんと食べるぽん。',
        'え、それだけ？w\n栄養足りてるぽん？無理な食事制限は続かないぽんよ。',
        'ストイックすぎて逆に心配ぽん。\n${label}${mealCalories}kcalはさすがに少ないぽん。食べるべきものは食べるぽん。',
      ];
      return PontaFeedback(message: msgs[v]);
    }
  }
}

class PontaFeedback {
  final String message;

  PontaFeedback({required this.message});
}

class FoodItem {
  final String name;
  final String amount;
  final int calories;

  FoodItem({required this.name, required this.amount, required this.calories});
}

class CalorieResult {
  final String foodName;
  final int calories;
  final String description;
  final String confidence;
  final List<FoodItem> items;

  CalorieResult({
    required this.foodName,
    required this.calories,
    required this.description,
    required this.confidence,
    this.items = const [],
  });
}
