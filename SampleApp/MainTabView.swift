import ScaryCatScreeningKit
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ForEach(ScreenerType.allCases) { type in
                ScreeningTestView(screenerType: type)
                    .tabItem {
                        Label(
                            type.rawValue,
                            systemImage: type == .multiClass ? "list.bullet.rectangle" : "list.star"
                        ) // アイコンは適当です
                    }
                    .tag(type) //  tag を追加してタブの識別を明確に
            }
        }
    }
}
