#!/usr/bin/env python3
"""カロリースキャンのプロンプト/モデル比較用スクリプト。
lib/services/openai_service.dart の _prompt をそのまま使って画像を投げ、結果を表示する。
本番(Dart)と同じく生HTTPで叩く（SDK不使用）。

  python3 tools/scan_test.py 画像.jpg [画像2.jpg ...] [--model gpt-4o] [--runs 3] [--effort low]

--model  : gpt-* はOpenAI、claude-* はAnthropicへ振り分け（複数指定可: --model gpt-4o --model claude-sonnet-5）
--runs   : 同じ画像を何回投げるか（ブレの確認用）
--effort : Claudeのみ。low/medium/high（省略時はAPI既定=high）
--old    : 改修前（一塊推定・detail low）のプロンプトで投げる（gpt-4o比較用）
--json   : 各回の生JSONも表示
"""
import argparse, base64, json, os, re, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# $/1M tokens (input, output)
PRICES = {
    'gpt-4o': (2.5, 10), 'gpt-4.1': (2, 8), 'gpt-4.1-mini': (0.4, 1.6), 'gpt-5': (1.25, 10), 'gpt-5-mini': (0.25, 2),
    'claude-opus-5': (5, 25), 'claude-sonnet-5': (2, 10), 'claude-haiku-4-5': (1, 5),
}
USD_JPY = 150

def load_env():
    env = {}
    with open(os.path.join(ROOT, '.env')) as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                k, v = line.strip().split('=', 1)
                env[k] = v.strip().strip('"').strip("'")
    return env

def dart_prompt():
    src = open(os.path.join(ROOT, 'lib/services/openai_service.dart'), encoding='utf-8').read()
    return re.search(r"static const String _prompt = '''(.*?)''';", src, re.S).group(1)

OLD_PROMPT = '''この食べ物の画像を見て、以下の形式でJSONのみを返してください。説明は不要です。
{
  "food_name": "食べ物の名前（日本語）",
  "calories": 推定カロリー数値（整数）,
  "description": "簡単な説明（日本語、1文）",
  "confidence": "high/medium/low"
}'''

# Claude用の構造化出力スキーマ（Dartのプロンプト内JSONと同じ形）
SCHEMA = {
    'type': 'object',
    'properties': {
        'food_name': {'type': 'string'},
        'items': {'type': 'array', 'items': {
            'type': 'object',
            'properties': {'name': {'type': 'string'}, 'amount': {'type': 'string'}, 'calories': {'type': 'integer'}},
            'required': ['name', 'amount', 'calories'], 'additionalProperties': False}},
        'calories': {'type': 'integer'},
        'description': {'type': 'string'},
        'confidence': {'type': 'string', 'enum': ['high', 'medium', 'low']},
    },
    'required': ['food_name', 'items', 'calories', 'description', 'confidence'],
    'additionalProperties': False,
}

def post(url, headers, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={'Content-Type': 'application/json', **headers})
    t = time.time()
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return json.load(r), time.time() - t
    except urllib.error.HTTPError as e:
        raise SystemExit(f'HTTP {e.code} from {url}: {e.read().decode()[:500]}')

def call_openai(env, model, prompt, b64, detail):
    body = {
        'model': model, 'max_completion_tokens': 2000,
        'response_format': {'type': 'json_object'},
        'messages': [{'role': 'user', 'content': [
            {'type': 'text', 'text': prompt},
            {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{b64}', 'detail': detail}},
        ]}],
    }
    data, sec = post('https://api.openai.com/v1/chat/completions', {'Authorization': f'Bearer {env["OPENAI_API_KEY"]}'}, body)
    u = data['usage']
    return data['choices'][0]['message']['content'], u['prompt_tokens'], u['completion_tokens'], sec

def call_claude(env, model, prompt, b64, effort):
    body = {
        'model': model, 'max_tokens': 4000,
        'output_config': {'format': {'type': 'json_schema', 'schema': SCHEMA}},
        'messages': [{'role': 'user', 'content': [
            {'type': 'image', 'source': {'type': 'base64', 'media_type': 'image/jpeg', 'data': b64}},
            {'type': 'text', 'text': prompt},
        ]}],
    }
    if effort and 'haiku' not in model:  # Haiku 4.5はeffort非対応
        body['output_config']['effort'] = effort
    data, sec = post('https://api.anthropic.com/v1/messages',
                     {'x-api-key': env['ANTHROPIC_API_KEY'], 'anthropic-version': '2023-06-01'}, body)
    if data.get('stop_reason') == 'refusal':
        raise SystemExit(f'refusal: {data.get("stop_details")}')
    text = ''.join(b['text'] for b in data['content'] if b['type'] == 'text')
    u = data['usage']
    return text, u['input_tokens'], u['output_tokens'], sec

def run_one(env, model, prompt, b64, a):
    if model.startswith('claude'):
        return call_claude(env, model, prompt, b64, a.effort)
    return call_openai(env, model, prompt, b64, 'low' if a.old else 'high')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('images', nargs='+')
    ap.add_argument('--model', action='append')
    ap.add_argument('--runs', type=int, default=1)
    ap.add_argument('--effort', default=None)
    ap.add_argument('--old', action='store_true')
    ap.add_argument('--json', action='store_true')
    a = ap.parse_args()
    models = a.model or ['gpt-4o']
    env = load_env()
    prompt = OLD_PROMPT if a.old else dart_prompt()

    for img in a.images:
        b64 = base64.b64encode(open(img, 'rb').read()).decode()
        print(f'\n===== {os.path.basename(img)} =====')
        for model in models:
            totals, secs, yen = [], [], []
            for i in range(a.runs):
                content, tin, tout, sec = run_one(env, model, prompt, b64, a)
                m = re.search(r'\{[\s\S]*\}', content)
                parsed = json.loads(m.group(0))
                items = parsed.get('items') or []
                total = sum(int(x.get('calories', 0)) for x in items) if items else int(parsed.get('calories', 0))
                pin, pout = PRICES.get(model, (0, 0))
                cost = (tin * pin + tout * pout) / 1e6 * USD_JPY
                totals.append(total); secs.append(sec); yen.append(cost)
                summary = ' / '.join(f'{x["name"]}{x["amount"]}={x["calories"]}' for x in items) or parsed.get('food_name')
                print(f'  [{model} #{i+1}] {total:4d} kcal  {sec:4.1f}s  {cost:.2f}円  conf={parsed.get("confidence")}  {parsed.get("food_name")}: {summary}')
                if a.json:
                    print(json.dumps(parsed, ensure_ascii=False, indent=2))
            if a.runs > 1:
                spread = max(totals) - min(totals)
                print(f'  --> {model}: 平均{sum(totals)/len(totals):.0f}kcal (幅{min(totals)}-{max(totals)}, ブレ{spread}) 平均{sum(secs)/len(secs):.1f}s 平均{sum(yen)/len(yen):.2f}円')

if __name__ == '__main__':
    main()
