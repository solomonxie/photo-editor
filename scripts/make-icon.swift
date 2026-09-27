import AppKit
// usage: icon <out.png> <variant: light|dark|tinted>
let out = CommandLine.arguments[1], variant = CommandLine.arguments[2]
let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
let full = CGRect(x: 0, y: 0, width: S, height: S)
switch variant {
case "light":
    let g = CGGradient(colorsSpace: cs, colors: [c(1, 0.24, 0.44), c(1, 0.6, 0.24)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
case "dark":
    ctx.setFillColor(c(0.08, 0.08, 0.09)); ctx.fill(full)
default:
    ctx.setFillColor(c(0, 0, 0)); ctx.fill(full)
}
let ink: CGColor = variant == "tinted" ? c(1, 1, 1) : (variant == "dark" ? c(1, 0.36, 0.52) : c(1, 1, 1))
// Photo frame: rounded square outline, slightly rotated.
ctx.saveGState()
ctx.translateBy(x: 512, y: 470)
ctx.rotate(by: -0.12)
let frame = CGRect(x: -250, y: -230, width: 500, height: 460)
ctx.setStrokeColor(ink); ctx.setLineWidth(56); ctx.setLineJoin(.round)
ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 90, cornerHeight: 90, transform: nil)); ctx.strokePath()
// Mountain inside the frame.
ctx.setFillColor(ink)
let m = CGMutablePath()
m.move(to: CGPoint(x: -190, y: -170)); m.addLine(to: CGPoint(x: -60, y: 20)); m.addLine(to: CGPoint(x: 20, y: -70))
m.addLine(to: CGPoint(x: 80, y: -10)); m.addLine(to: CGPoint(x: 190, y: -170)); m.closeSubpath()
ctx.addPath(m); ctx.fillPath()
ctx.restoreGState()
// Sparkle, top-right, breaking out of the frame.
func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy + r))
    p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.12, y: cy + r * 0.12))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx + r * 0.12, y: cy - r * 0.12))
    p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.12, y: cy - r * 0.12))
    p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx - r * 0.12, y: cy + r * 0.12))
    ctx.addPath(p); ctx.fillPath()
}
if variant == "light" {
    ctx.setFillColor(c(0.98, 0.3, 0.45)); sparkle(752, 752, 200) // knock-out halo
}
ctx.setFillColor(ink)
sparkle(752, 752, 165)
sparkle(868, 590, 62)
let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
