import SwiftUI

@main
struct BangkkuApp: App {
    var body: some Scene {
        WindowGroup {
            BangkkuWebView()
                .ignoresSafeArea()
                .background(Color("LaunchBackground").ignoresSafeArea())
                .preferredColorScheme(.light)
        }
    }
}
