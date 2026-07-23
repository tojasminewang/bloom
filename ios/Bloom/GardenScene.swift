// GardenScene.swift — banner.js port: layered garden hills, and the meadow scene
// where your real plants stand, sized by level, tallest in the middle.
import SwiftUI

private func pine(_ ctx: GraphicsContext, x: Double, y: Double, h: Double, _ f: Color) {
    let w = h * 0.42
    var p1 = Path()
    p1.move(to: CGPoint(x: x, y: y - h))
    p1.addLine(to: CGPoint(x: x + w, y: y - h * 0.35))
    p1.addLine(to: CGPoint(x: x - w, y: y - h * 0.35))
    p1.closeSubpath()
    ctx.fill(p1, with: .color(f))
    var p2 = Path()
    p2.move(to: CGPoint(x: x, y: y - h * 0.72))
    p2.addLine(to: CGPoint(x: x + w * 1.25, y: y))
    p2.addLine(to: CGPoint(x: x - w * 1.25, y: y))
    p2.closeSubpath()
    ctx.fill(p2, with: .color(f))
}

private func sceneFrond(_ ctx: GraphicsContext, x: Double, y: Double, h: Double, _ f: Color) {
    var stem = Path()
    stem.move(to: CGPoint(x: x, y: y))
    stem.addLine(to: CGPoint(x: x, y: y - h))
    ctx.stroke(stem, with: .color(f), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    for i in 0..<4 {
        let t = Double(i + 1) / 5
        let yy = y - h * t - h * 0.06
        let len = h * 0.32 * (1 - t * 0.4)
        var l = Path()
        l.move(to: CGPoint(x: x, y: yy))
        l.addQuadCurve(to: CGPoint(x: x - len, y: yy + len * 0.12), control: CGPoint(x: x - len * 0.7, y: yy - len * 0.3))
        l.move(to: CGPoint(x: x, y: yy))
        l.addQuadCurve(to: CGPoint(x: x + len, y: yy + len * 0.12), control: CGPoint(x: x + len * 0.7, y: yy - len * 0.3))
        ctx.stroke(l, with: .color(f), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }
    ctx.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: y - h - 2.4, width: 4.8, height: 4.8)), with: .color(f))
}

private func bush(_ ctx: GraphicsContext, x: Double, y: Double, r: Double, _ f: Color) {
    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.5 - r * 0.72, width: r * 2, height: r * 1.44)), with: .color(f))
}

private func hillPath(_ points: [(Double, Double)], H: Double, W: Double) -> Path {
    // "M0 H L0 y0 Q c1 … L W H Z" — smooth ridge built from quad segments
    var p = Path()
    p.move(to: CGPoint(x: 0, y: H))
    p.addLine(to: CGPoint(x: 0, y: points[0].1))
    var i = 1
    while i + 1 < points.count {
        p.addQuadCurve(to: CGPoint(x: points[i + 1].0, y: points[i + 1].1),
                       control: CGPoint(x: points[i].0, y: points[i].1))
        i += 2
    }
    p.addLine(to: CGPoint(x: W, y: H))
    p.closeSubpath()
    return p
}

/// Empty-garden banner: hills, trees, a few meadow flowers. viewBox 1000×240.
struct GardenHillsView: View {
    @Environment(\.theme) private var theme
    var seed: String = "bloom-hills-0"
    var trees: Int = 10
    var flowers: Int = 4

    var body: some View {
        Canvas { ctx, size in
            let W = 1000.0, H = 240.0
            ctx.scaleBy(x: size.width / W, y: size.height / H)
            var rnd = PlantRandom(seed: seed)

            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .linearGradient(
                Gradient(colors: [theme.hsky1, theme.hsky2]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
            ctx.fill(Path(ellipseIn: CGRect(x: 872 - 26, y: 46 - 26, width: 52, height: 52)), with: .color(theme.hsun))
            ctx.fill(Path(ellipseIn: CGRect(x: 180 - 12, y: 38 - 12, width: 24, height: 24)), with: .color(theme.hsun.opacity(0.5)))

            // ridge geometry from banner.js (Q + T smooth continuations, precomputed)
            let layers: [(path: Path, tree: Color, ridge: Double, hMin: Double, hMax: Double)] = [
                (hillPath([(0, 148), (120, 116), (260, 136), (400, 156), (520, 126), (640, 96), (780, 140), (890, 184), (1000, 124)], H: H, W: W), theme.htree1, 136, 22, 36),
                (hillPath([(0, 180), (150, 150), (330, 168), (510, 186), (660, 158), (810, 130), (1000, 170)], H: H, W: W), theme.htree2, 168, 20, 32),
                (hillPath([(0, 206), (200, 184), (430, 198), (660, 212), (1000, 192)], H: H, W: W), theme.htree3, 200, 16, 28),
            ]
            let fills = [theme.hill1, theme.hill2, theme.hill3]
            let perLayer = [Int(ceil(Double(trees) * 0.4)), Int(ceil(Double(trees) * 0.33)), Int(floor(Double(trees) * 0.27))]
            for (li, layer) in layers.enumerated() {
                ctx.fill(layer.path, with: .color(fills[li]))
                for _ in 0..<perLayer[li] {
                    let x = (24 + rnd.next() * (W - 48)).rounded()
                    let y = layer.ridge + 12 + rnd.next() * 12
                    let h = layer.hMin + rnd.next() * (layer.hMax - layer.hMin)
                    let kind = rnd.next()
                    if kind < 0.46 { pine(ctx, x: x, y: y, h: h, layer.tree) }
                    else if kind < 0.92 { sceneFrond(ctx, x: x, y: y, h: h, layer.tree) }
                    else { bush(ctx, x: x, y: y, r: h * 0.32, layer.tree) }
                }
            }
            for _ in 0..<flowers {
                let x = (30 + rnd.next() * (W - 60)).rounded()
                let y = 216 + rnd.next() * 16
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)), with: .color(theme.hflower))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(theme.hsun))
            }
        }
    }
}

struct ScenePlant: Identifiable {
    var id: String { spec.id }
    var spec: PlantSpec
    var level: Int
    var name: String
}

/// Your real garden: every plant standing in the meadow, sized by its level.
struct GardenSceneView: View {
    @Environment(\.theme) private var theme
    var plants: [ScenePlant]
    var selectedId: String?
    var onTap: (String) -> Void = { _ in }

    private struct Placed: Identifiable {
        var id: String { plant.id }
        var plant: ScenePlant
        var x: Double
        var y: Double
        var w: Double
    }

    private var placed: [Placed] {
        var rnd = PlantRandom(seed: plants.map(\.spec.id).joined())
        // burn the PRNG calls the backdrop consumed (2 layers × 4 trees × 3 calls)
        for _ in 0..<24 { _ = rnd.next() }
        let W = 1000.0
        let sorted = plants.sorted { $0.level > $1.level }
        var order: [ScenePlant] = []
        for (i, p) in sorted.enumerated() {
            if i % 2 == 0 { order.append(p) } else { order.insert(p, at: 0) }
        }
        let n = order.count
        let gap = n > 1 ? min(130, (W - 180) / Double(n - 1)) : 0
        let startX = W / 2 - gap * Double(n - 1) / 2
        return order.enumerated().map { i, p in
            let w = 58 + Double(min(p.level, 12)) * 4
            let y = 240 + (rnd.next() * 10 - 5)
            return Placed(plant: p, x: startX + gap * Double(i), y: y, w: w)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 1000
            ZStack(alignment: .topLeading) {
                backdrop
                ForEach(placed) { pl in
                    let h = pl.w * 1.25
                    PlantView(spec: pl.plant.spec, level: pl.plant.level)
                        .frame(width: pl.w * s, height: h * s)
                        .position(x: pl.x * s, y: (pl.y - h / 2) * s)
                        .scaleEffect(pl.plant.id == selectedId ? 1.06 : 1, anchor: .bottom)
                        .onTapGesture { onTap(pl.plant.id) }
                }
            }
        }
        .aspectRatio(1000 / 260, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var backdrop: some View {
        Canvas { ctx, size in
            let W = 1000.0, H = 260.0
            ctx.scaleBy(x: size.width / W, y: size.height / H)
            var rnd = PlantRandom(seed: plants.map(\.spec.id).joined())

            ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .linearGradient(
                Gradient(colors: [theme.hsky1, theme.hsky2]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: H)))
            ctx.fill(Path(ellipseIn: CGRect(x: 872 - 26, y: 46 - 26, width: 52, height: 52)), with: .color(theme.hsun))
            ctx.fill(Path(ellipseIn: CGRect(x: 180 - 12, y: 38 - 12, width: 24, height: 24)), with: .color(theme.hsun.opacity(0.5)))

            let back: [(path: Path, tree: Color, ridge: Double, fill: Color)] = [
                (hillPath([(0, 150), (120, 118), (260, 138), (400, 158), (520, 128), (640, 98), (780, 142), (890, 186), (1000, 126)], H: H, W: W), theme.htree1, 138, theme.hill1),
                (hillPath([(0, 184), (150, 154), (330, 172), (510, 190), (660, 162), (830, 134), (1000, 174)], H: H, W: W), theme.htree2, 172, theme.hill2),
            ]
            for layer in back {
                ctx.fill(layer.path, with: .color(layer.fill))
                for _ in 0..<4 {
                    let x = (24 + rnd.next() * (W - 48)).rounded()
                    let y = layer.ridge + 10 + rnd.next() * 10
                    let h = 18 + rnd.next() * 14
                    pine(ctx, x: x, y: y, h: h, layer.tree)
                }
            }
            // front meadow the plants stand on
            ctx.fill(hillPath([(0, 218), (250, 204), (500, 212), (750, 220), (1000, 208)], H: H, W: W), with: .color(theme.hill3))
        }
    }
}
