import Foundation

struct NikonCloudCatalog: Decodable {
    let schemaVersion: Int
    let renderer: String
    let accuracy: String
    let presetCount: Int
    let presets: [NikonCloudPreset]
}

struct NikonCloudPreset: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let filename: String
    let sourceBytes: Int
    let hasCustomToneCurve: Bool
    let tone: NikonCloudTone
    let grading: NikonCloudGrading
    let mixer: [NikonCloudColorMix]
    let toneCurve: [Double]

    /// Applies the device-side SDR approximation used by live photo and video
    /// monitoring. Capture and recording pipelines continue to receive the
    /// original frame before this display-only transform.
    func applyingPreviewEffect(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        var r = Self.clamp(red)
        var g = Self.clamp(green)
        var b = Self.clamp(blue)
        var luma = Self.clamp(r * 0.2126 + g * 0.7152 + b * 0.0722)

        let contrast = 1 + tone.contrast / 120
        r = (r - 0.5) * contrast + 0.5
        g = (g - 0.5) * contrast + 0.5
        b = (b - 0.5) * contrast + 0.5

        let shadows = pow(1 - luma, 2)
        let midtones = 1 - abs(luma * 2 - 1)
        let highlights = pow(luma, 2)
        let tonalShift =
            tone.shadows / 400 * shadows
            + tone.highlights / 400 * highlights
            + tone.blacks / 500 * pow(1 - luma, 4)
            + tone.whites / 500 * pow(luma, 4)
        r += tonalShift
        g += tonalShift
        b += tonalShift

        luma = Self.clamp(r * 0.2126 + g * 0.7152 + b * 0.0722)
        let saturation = max(0, 1 + tone.saturation / 100)
        r = luma + (r - luma) * saturation
        g = luma + (g - luma) * saturation
        b = luma + (b - luma) * saturation

        let gradeX = grading.lift.x / 800 * shadows
            + grading.gamma.x / 800 * midtones
            + grading.gain.x / 800 * highlights
        let gradeY = grading.lift.y / 800 * shadows
            + grading.gamma.y / 800 * midtones
            + grading.gain.y / 800 * highlights
        r += gradeX - gradeY * 0.5
        g += gradeY - gradeX * 0.5
        b -= (gradeX + gradeY) * 0.5

        if toneCurve.count > 1 {
            r = curveValue(for: Self.clamp(r))
            g = curveValue(for: Self.clamp(g))
            b = curveValue(for: Self.clamp(b))
        }
        return applyingColorMixer(red: r, green: g, blue: b)
    }

    func applyingColorMixer(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        guard mixer.count == 8 else { return (red, green, blue) }
        var hsl = Self.rgbToHSL(
            red: Self.clamp(red),
            green: Self.clamp(green),
            blue: Self.clamp(blue)
        )
        let anchors = [0.0, 30, 60, 120, 180, 240, 280, 330]
        var totalWeight = 0.0
        var hueShift = 0.0
        var chromaShift = 0.0
        var brightnessShift = 0.0
        for (index, anchor) in anchors.enumerated() {
            let direct = abs(hsl.hue - anchor)
            let distance = min(direct, 360 - direct)
            let weight = max(0, 1 - distance / 60)
            totalWeight += weight
            hueShift += Double(mixer[index].hue) * weight
            chromaShift += Double(mixer[index].chroma) * weight
            brightnessShift += Double(mixer[index].brightness) * weight
        }
        if totalWeight > 0 {
            hsl.hue = (hsl.hue + hueShift / totalWeight * 0.5)
                .truncatingRemainder(dividingBy: 360)
            if hsl.hue < 0 { hsl.hue += 360 }
            hsl.saturation = Self.clamp(
                hsl.saturation * (1 + chromaShift / totalWeight / 64)
            )
            hsl.lightness = Self.clamp(
                hsl.lightness + brightnessShift / totalWeight / 255
            )
        }
        return Self.hslToRGB(
            hue: hsl.hue,
            saturation: hsl.saturation,
            lightness: hsl.lightness
        )
    }

    private static func rgbToHSL(
        red: Double,
        green: Double,
        blue: Double
    ) -> (hue: Double, saturation: Double, lightness: Double) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum
        let lightness = (maximum + minimum) / 2
        guard delta > 0.000_001 else {
            return (0, 0, lightness)
        }
        let saturation = delta / max(
            0.000_001,
            1 - abs(2 * lightness - 1)
        )
        let hue: Double
        if maximum == red {
            hue = 60 * ((green - blue) / delta).truncatingRemainder(
                dividingBy: 6
            )
        } else if maximum == green {
            hue = 60 * ((blue - red) / delta + 2)
        } else {
            hue = 60 * ((red - green) / delta + 4)
        }
        return (hue < 0 ? hue + 360 : hue, saturation, lightness)
    }

    private static func hslToRGB(
        hue: Double,
        saturation: Double,
        lightness: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = hue / 60
        let secondary = chroma * (1 - abs(sector.truncatingRemainder(
            dividingBy: 2
        ) - 1))
        let components: (Double, Double, Double)
        switch sector {
        case 0..<1: components = (chroma, secondary, 0)
        case 1..<2: components = (secondary, chroma, 0)
        case 2..<3: components = (0, chroma, secondary)
        case 3..<4: components = (0, secondary, chroma)
        case 4..<5: components = (secondary, 0, chroma)
        default: components = (chroma, 0, secondary)
        }
        let match = lightness - chroma / 2
        return (
            clamp(components.0 + match),
            clamp(components.1 + match),
            clamp(components.2 + match)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func curveValue(for input: Double) -> Double {
        let scaled = input * Double(toneCurve.count - 1)
        let lower = min(toneCurve.count - 1, max(0, Int(floor(scaled))))
        let upper = min(toneCurve.count - 1, lower + 1)
        let amount = scaled - Double(lower)
        return Self.clamp(
            toneCurve[lower] + (toneCurve[upper] - toneCurve[lower]) * amount
        )
    }
}

struct NikonCloudTone: Decodable, Equatable {
    let contrast: Double
    let highlights: Double
    let shadows: Double
    let whites: Double
    let blacks: Double
    let saturation: Double
    let texture: Double
    let clarity: Double
    let sharpening: Double
}

struct NikonCloudGrading: Decodable, Equatable {
    let gain: NikonCloudGradePoint
    let gamma: NikonCloudGradePoint
    let lift: NikonCloudGradePoint
}

struct NikonCloudGradePoint: Decodable, Equatable {
    let x: Double
    let y: Double
}

struct NikonCloudColorMix: Decodable, Equatable {
    let hue: Int
    let chroma: Int
    let brightness: Int
}

struct NikonCloudPresetGroup: Identifiable {
    let title: String
    let presets: [NikonCloudPreset]
    var id: String { title }
}

enum NikonCloudPresetLibrary {
    static let catalog: NikonCloudCatalog = {
        guard let url = Bundle.main.url(
            forResource: "nikon-cloud-presets",
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode(NikonCloudCatalog.self, from: data)
        else {
            return NikonCloudCatalog(
                schemaVersion: 1,
                renderer: "unavailable",
                accuracy: "approximate-sdr-preview",
                presetCount: 0,
                presets: []
            )
        }
        return decoded
    }()

    static var presets: [NikonCloudPreset] { catalog.presets }

    static var groups: [NikonCloudPresetGroup] {
        let definitions: [(String, ClosedRange<Character>)] = [
            ("A–F", "A"..."F"),
            ("G–L", "G"..."L"),
            ("M–R", "M"..."R"),
            ("S–Z", "S"..."Z")
        ]
        var result = definitions.map { definition in
            NikonCloudPresetGroup(
                title: definition.0,
                presets: presets.filter { preset in
                    guard let first = preset.name.uppercased().first else {
                        return false
                    }
                    return definition.1.contains(first)
                }
            )
        }
        let groupedIDs = Set(result.flatMap { $0.presets.map(\.id) })
        let remaining = presets.filter { !groupedIDs.contains($0.id) }
        if !remaining.isEmpty {
            result.append(NikonCloudPresetGroup(
                title: "其他",
                presets: remaining
            ))
        }
        return result.filter { !$0.presets.isEmpty }
    }
}
