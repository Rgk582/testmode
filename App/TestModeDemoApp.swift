import SwiftUI

@main
struct TestModeDemoApp: App {
    var body: some Scene {
        WindowGroup {
            WebHost()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}

/// Hosts the UIKit web view controller. UIKit is used so the alert and banners behave exactly like system UI.
struct WebHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController { WebViewController() }
    func updateUIViewController(_ controller: WebViewController, context: Context) {}
}
