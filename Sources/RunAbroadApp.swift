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
            if model.page == .results {
                ResultsView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                switch model.uiStyle {
                case .cards:
                    FormView()
                        .transition(.opacity)
                case .dashboard:
                    LookerView()
                        .transition(.opacity)
                case .wizard:
                    WizardView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.snappy(duration: 0.28), value: model.page)
    }
}
