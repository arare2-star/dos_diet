import 'dart:convert';
import 'dart:io';
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
          calories: (parsed['calories'] as num?)?.toInt() ?? 0,
          description: parsed['description'] ?? '',
          confidence: parsed['confidence'] ?? 'low',
        );
      }
    }

    throw Exception('カロリー推定に失敗しました (${response.statusCode})');
  }

  /// ぽんたコーチからのフィードバックを生成（辛口キャラ）
  static PontaFeedback getPontaFeedback(int calories, int totalToday, int dailyGoal) {
    final remaining = dailyGoal - totalToday;
    final ratio = totalToday / dailyGoal;

    if (ratio >= 1.5) {
      return PontaFeedback(
        message: 'はあ？！${totalToday}kcalって正気？\nもう今日は水だけ飲んどけ。',
        imagePath: 'assets/images/ponta_angry.png',
      );
    } else if (ratio >= 1.2) {
      return PontaFeedback(
        message: 'オーバーしてるじゃん。反省した？\n${(-remaining)}kcal食いすぎ。明日からちゃんとやれよ。',
        imagePath: 'assets/images/ponta_shocked.png',
      );
    } else if (ratio >= 1.0) {
      return PontaFeedback(
        message: 'ギリギリアウトだ。\nあと少しで収まったのに…詰めが甘すぎ。',
        imagePath: 'assets/images/ponta_shocked.png',
      );
    } else if (ratio >= 0.8) {
      return PontaFeedback(
        message: 'まあ…悪くはないけど。\nあと${remaining}kcalは残ってるぞ。油断すんな。',
        imagePath: 'assets/images/ponta_default.png',
      );
    } else if (calories > 700) {
      return PontaFeedback(
        message: 'その一食でかなり使ったな。\n次は軽めにしろよ。わかった？',
        imagePath: 'assets/images/ponta_default.png',
      );
    } else if (ratio <= 0.5) {
      return PontaFeedback(
        message: 'おっ、今日はやるじゃん！🎉\n${remaining}kcalも余ってる！その調子で続けろよ！',
        imagePath: 'assets/images/ponta_happy.png',
      );
    } else {
      return PontaFeedback(
        message: 'ちゃんと記録できてるじゃないか。\nこれを毎日続けろよ。逃げるなよ。',
        imagePath: 'assets/images/ponta_default.png',
      );
    }
  }
}

class PontaFeedback {
  final String message;
  final String imagePath;

  PontaFeedback({required this.message, required this.imagePath});
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
