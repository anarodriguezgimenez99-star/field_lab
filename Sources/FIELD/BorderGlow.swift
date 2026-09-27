import SwiftUI

/// A quiet, dark card whose edge light follows the pointer instead of running
/// continuously. The interaction is intentionally local: it acknowledges
/// where the pointer is without moving the content underneath it.
struct BorderGlowCard<Content: View>: View {
    let edgeSensitivity: Double
    let glowColor: Color
    let backgroundColor: Color
    let borderRadius: CGFloat
    let glowRadius: CGFloat
    let glowIntensity: Double
    let coneSpread: Double
    let animated: Bool
    let colors: [Color]
    let fillOpacity: Double
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var edgeProximity = 0.0
    @State private var cursorAngle = 45.0
    @State private var isHovering = false

    init(
        edgeSensitivity: Double = 30,
        // HSL 40 80% 80%, matching the supplied glowColor value.
        glowColor: Color = Color(red: 0.96, green: 0.853, blue: 0.64),
        backgroundColor: Color = Color(red: 0.071, green: 0.059, blue: 0.090),
        borderRadius: CGFloat = 28,
        glowRadius: CGFloat = 40,
        glowIntensity: Double = 1,
        coneSpread: Double = 25,
        animated: Bool = false,
        colors: [Color] = [
            Color(red: 0.753, green: 0.518, blue: 0.988),
            Color(red: 0.957, green: 0.447, blue: 0.706),
            Color(red: 0.220, green: 0.573, blue: 0.973)
        ],
        fillOpacity: Double = 0.5,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.edgeSensitivity = edgeSensitivity
        self.glowColor = glowColor
        self.backgroundColor = backgroundColor
        self.borderRadius = borderRadius
        self.glowRadius = glowRadius
        self.glowIntensity = glowIntensity
        self.coneSpread = coneSpread
        self.animated = animated
        self.colors = colors
        self.fillOpacity = fillOpacity
        self.content = content
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
                .fill(backgroundColor)

            edgeFill
                .clipShape(RoundedRectangle(cornerRadius: borderRadius, style: .continuous))

            content()
                .zIndex(1)

            edgeBorder
                .zIndex(2)

            outerGlow
                .zIndex(3)
        }
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: borderRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: borderRadius, style: .continuous))
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .allowsHitTesting(false)
                    .onAppear { currentSize = proxy.size }
                    .onChange(of: proxy.size) { _, newSize in currentSize = newSize }
            }
        }
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let location):
                updatePointer(location)
                isHovering = true
            case .ended:
                isHovering = false
                if reduceMotion {
                    edgeProximity = 0
                } else {
                    withAnimation(.easeOut(duration: 0.22)) {
                        edgeProximity = 0
                    }
                }
            }
        }
        .onChange(of: isHovering) { _, hovering in
            guard animated, hovering, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                edgeProximity = max(edgeProximity, 0.68)
            }
        }
    }

    private var colorOpacity: Double {
        let sensitivity = min(edgeSensitivity + 20, 99)
        return max(0, min(1, (edgeProximity * 100 - sensitivity) / (100 - sensitivity))) * glowIntensity
    }

    private var glowOpacity: Double {
        max(0, min(1, (edgeProximity * 100 - edgeSensitivity) / (100 - edgeSensitivity))) * glowIntensity
    }

    private var edgeFill: some View {
        RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
            .fill(
                AngularGradient(
                    gradient: Gradient(colors: normalizedColors.map { $0.opacity(fillOpacity) }),
                    center: .center,
                    startAngle: .degrees(cursorAngle - 180),
                    endAngle: .degrees(cursorAngle + 180)
                )
            )
            .opacity(colorOpacity)
            .blendMode(.plusLighter)
    }

    private var edgeBorder: some View {
        RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
            .strokeBorder(directionalGradient, lineWidth: 1.5)
            .opacity(colorOpacity)
    }

    private var outerGlow: some View {
        RoundedRectangle(cornerRadius: borderRadius, style: .continuous)
            .stroke(glowColor.opacity(min(glowOpacity * 0.70, 1)), lineWidth: 2)
            .blur(radius: min(glowRadius * 0.42, 18))
            .padding(-glowRadius * 0.28)
            .allowsHitTesting(false)
    }

    private var directionalGradient: AngularGradient {
        let visibleSpread = max(0.05, min(coneSpread / 100, 0.45))
        let shoulder = visibleSpread * 0.60
        let center = 0.5
        let stops = [
            Gradient.Stop(color: .clear, location: 0),
            Gradient.Stop(color: .clear, location: center - visibleSpread),
            Gradient.Stop(color: normalizedColors[0].opacity(0.32), location: center - shoulder),
            Gradient.Stop(color: normalizedColors[1].opacity(0.95), location: center),
            Gradient.Stop(color: normalizedColors[2].opacity(0.32), location: center + shoulder),
            Gradient.Stop(color: .clear, location: center + visibleSpread),
            Gradient.Stop(color: .clear, location: 1)
        ]

        return AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .degrees(cursorAngle - 180),
            endAngle: .degrees(cursorAngle + 180)
        )
    }

    private var normalizedColors: [Color] {
        if colors.isEmpty { return [.white, .white, .white] }
        if colors.count == 1 { return [colors[0], colors[0], colors[0]] }
        if colors.count == 2 { return [colors[0], colors[1], colors[0]] }
        return Array(colors.prefix(3))
    }

    private func updatePointer(_ location: CGPoint) {
        updatePointer(location, in: currentSize)
    }

    @State private var currentSize = CGSize(width: 1, height: 1)

    private func updatePointer(_ location: CGPoint, in size: CGSize) {
        let centerX = max(size.width / 2, 1)
        let centerY = max(size.height / 2, 1)
        let dx = location.x - centerX
        let dy = location.y - centerY
        let proximity = min(1, max(abs(dx) / centerX, abs(dy) / centerY))
        var degrees = atan2(dy, dx) * 180 / .pi + 90
        if degrees < 0 { degrees += 360 }
        edgeProximity = proximity
        cursorAngle = degrees
    }
}
