import SwiftUI

@main
struct RunAbroadApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.blue)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            if model.page == .form {
                FormView()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                ResultsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.28), value: model.page)
    }
}
