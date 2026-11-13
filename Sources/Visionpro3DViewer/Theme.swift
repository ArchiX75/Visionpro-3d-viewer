import SwiftUI

/// Thème visuel de l'application : fond sombre dégradé, accents indigo → cyan,
/// surfaces en verre dépoli (`material`) et liserés dégradés.
enum Theme {
    /// Accent principal de l'interface.
    static let accent = LinearGradient(
        colors: [.indigo, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Fond principal de l'app.
    static let background = LinearGradient(
        colors: [
            Color(red: 0.035, green: 0.045, blue: 0.10),
            Color(red: 0.09, green: 0.05, blue: 0.17)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Fond d'écran : dégradé sombre + halos lumineux discrets.
struct BackgroundView: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [.cyan.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [.indigo.opacity(0.20), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}
