import SwiftUI

// Pittsburgh Steelers Color Scheme
struct SteelersTheme {
    // Primary Colors
    static let steelersBlack = Color(red: 0.0, green: 0.0, blue: 0.0) // #000000
    static let steelersGold = Color(red: 1.0, green: 0.713, blue: 0.071) // #FFB612 (official Steelers gold)
    
    // Accent Colors
    static let darkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let lightGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let goldAccent = Color(red: 1.0, green: 0.8, blue: 0.2) // Lighter gold for highlights
    
    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.8)
    static let textOnGold = Color.black
    
    // Card Colors
    static let cardBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let cardBorder = steelersGold.opacity(0.3)
}

// Custom View Modifiers for Steelers Theme
struct SteelersCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SteelersTheme.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(SteelersTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: SteelersTheme.steelersGold.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct SteelersButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(isPrimary ? SteelersTheme.textOnGold : SteelersTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isPrimary ? SteelersTheme.steelersGold : SteelersTheme.darkGray
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

extension View {
    func steelersCard() -> some View {
        modifier(SteelersCardStyle())
    }
    
    func steelersButton(isPrimary: Bool = true) -> some View {
        buttonStyle(SteelersButtonStyle(isPrimary: isPrimary))
    }
}

