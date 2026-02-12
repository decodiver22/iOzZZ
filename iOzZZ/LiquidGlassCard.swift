//
//  LiquidGlassCard.swift
//  iOzZZ
//
//  Reusable liquid glass effect card component with frosted glass,
//  gradient highlights, and layered shadows for a premium glassmorphic look.
//

import SwiftUI

/// A card with liquid glass effect: frosted background, gradient overlay, and glowing borders.
struct LiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    let showShadows: Bool
    @ViewBuilder let content: () -> Content

    init(
        cornerRadius: CGFloat = 24,
        padding: EdgeInsets = EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28),
        showShadows: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.showShadows = showShadows
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(glassBackground)
            .if(showShadows) { view in
                view
                    .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
                    .shadow(color: .blue.opacity(0.2), radius: 20, y: 10)
            }
    }

    private var glassBackground: some View {
        ZStack {
            // Base frosted glass
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .opacity(0.6)

            // Gradient highlight overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.15), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Border highlight
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
}

/// View extension to conditionally apply modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    ZStack {
        // Dark gradient background
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.15), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        LiquidGlassCard {
            VStack(spacing: 16) {
                Text("72:00")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                HStack {
                    Text("Morning Alarm")
                        .font(.title3.weight(.semibold))
                    Text("•")
                    Text("Weekdays")
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding()
    }
}
