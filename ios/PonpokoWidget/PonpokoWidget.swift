import WidgetKit
import SwiftUI

// ぽんぽこのホーム画面ウィジェット。
// データはFlutter側（lib/services/home_widget_service.dart）が
// App GroupのUserDefaultsに書き込み、記録のたびにreloadされる。

private let appGroupId = "group.com.example.dosDiet"

struct CalorieEntry: TimelineEntry {
    let date: Date
    let total: Int
    let goal: Int
    let streak: Int
}

struct Provider: TimelineProvider {
    private func load() -> CalorieEntry {
        let ud = UserDefaults(suiteName: appGroupId)
        var total = ud?.integer(forKey: "total") ?? 0
        let goalRaw = ud?.integer(forKey: "goal") ?? 0
        let goal = goalRaw > 0 ? goalRaw : 2000
        let streak = ud?.integer(forKey: "streak") ?? 0

        // 保存された日付が今日でなければ未記録扱い（0時を跨いだ直後など）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d"
        let saved = ud?.string(forKey: "date") ?? ""
        if saved != formatter.string(from: Date()) {
            total = 0
        }
        return CalorieEntry(date: Date(), total: total, goal: goal, streak: streak)
    }

    func placeholder(in context: Context) -> CalorieEntry {
        CalorieEntry(date: Date(), total: 1200, goal: 2000, streak: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieEntry>) -> Void) {
        // 次の0時に組み直して「今日」の表示をリセットする
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        completion(Timeline(entries: [load()], policy: .after(midnight)))
    }
}

struct PonpokoWidgetView: View {
    var entry: CalorieEntry

    // アプリのAppTheme（theme.dart）と同じ暖色パレット
    private let orange = Color(red: 1.00, green: 0.54, blue: 0.40) // FF8A65
    private let brown = Color(red: 0.31, green: 0.20, blue: 0.18)  // 4E342E
    private let danger = Color(red: 0.94, green: 0.33, blue: 0.31) // EF5350
    private let cream = Color(red: 1.00, green: 0.97, blue: 0.94)  // FFF8F0

    var body: some View {
        let remaining = entry.goal - entry.total
        let over = remaining < 0
        let progress = entry.goal > 0
            ? min(Double(entry.total) / Double(entry.goal), 1.0) : 0.0

        VStack(spacing: 8) {
            HStack(spacing: 4) {
                // ぽんぽこの顔（PontaPuppetの頭パーツと同じ素材）
                if let head = UIImage(named: "ponta_head") {
                    Image(uiImage: head)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22)
                }
                Text("ぽんぽこ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(brown.opacity(0.65))
                Spacer()
                if entry.streak > 0 {
                    Text("🔥\(entry.streak)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(brown.opacity(0.65))
                }
            }
            ZStack {
                Circle()
                    .stroke(orange.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(over ? danger : orange,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(over ? "+\(-remaining)" : "\(remaining)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(over ? danger : brown)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(over ? "オーバー🔥" : "のこりkcal")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(brown.opacity(0.55))
                }
                .padding(.horizontal, 12)
            }
        }
        .containerBackground(for: .widget) { cream }
    }
}

@main
struct PonpokoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PonpokoWidget", provider: Provider()) { entry in
            PonpokoWidgetView(entry: entry)
        }
        .configurationDisplayName("ぽんぽこ")
        .description("今日ののこりカロリーが見えるぽん")
        .supportedFamilies([.systemSmall])
    }
}
