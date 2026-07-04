import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  /// 画像からカロリーを推測する
  static Future<CalorieResult> estimateCaloriesFromImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'max_tokens': 500,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''この食べ物の画像を見て、以下の形式でJSONのみを返してください。説明は不要です。
{
  "food_name": "食べ物の名前（日本語）",
  "calories": 推定カロリー数値（整数）,
  "description": "簡単な説明（日本語、1文）",
  "confidence": "high/medium/low"
}''',
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                  'detail': 'low',
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'] as String;

      // JSONを抽出してパース
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!);
        return CalorieResult(
          foodName: parsed['food_name'] ?? '不明な食べ物',
          calories: _dejitterRound((parsed['calories'] as num?)?.toInt() ?? 0),
          description: parsed['description'] ?? '',
          confidence: parsed['confidence'] ?? 'low',
        );
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

class CalorieResult {
  final String foodName;
  final int calories;
  final String description;
  final String confidence;

  CalorieResult({
    required this.foodName,
    required this.calories,
    required this.description,
    required this.confidence,
  });
}
