import Foundation

/// Matches only the exact known firmware bitmap. Menus, errors and guest data
/// are left visible; source framebuffer and persistent firmware stay untouched.
public struct BootArtwork: Codable, Sendable {
    public struct Sample: Codable, Sendable {
        public let x: Int
        public let y: Int
        public let red: UInt8
        public let green: UInt8
        public let blue: UInt8
        public init(x: Int, y: Int, red: UInt8, green: UInt8, blue: UInt8) {
            self.x = x; self.y = y; self.red = red; self.green = green; self.blue = blue
        }
    }
    public let width: Int
    public let height: Int
    public let samples: [Sample]
    public init(width: Int, height: Int, samples: [Sample]) {
        self.width = width; self.height = height; self.samples = samples
    }
    public func displayBytes(_ original: Data, frameWidth: Int, frameHeight: Int) -> Data {
        guard width >= 64, height >= 40, width <= frameWidth, height <= frameHeight,
              original.count == frameWidth*frameHeight*4, samples.count >= 32,
              samples.allSatisfy({ (0..<width).contains($0.x) && (0..<height).contains($0.y) }) else { return original }
        let left = (frameWidth-width)/2
        let candidates = [(frameHeight-height)/2, Int(Double(frameHeight)*0.382)-height/2]
        let top = original.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int? in
            for top in candidates where top >= 0 && top+height <= frameHeight {
                if samples.allSatisfy({ point in
                    let index = ((top+point.y)*frameWidth+left+point.x)*4
                    return abs(Int(buffer[index])-Int(point.blue)) <= 6 &&
                           abs(Int(buffer[index+1])-Int(point.green)) <= 6 &&
                           abs(Int(buffer[index+2])-Int(point.red)) <= 6
                }) { return top }
            }
            return nil
        }
        guard let top else { return original }
        var output = original
        output.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            for y in 0..<height {
                for x in 0..<width {
                    let index = ((top+y)*frameWidth+left+x)*4
                    buffer[index] = 0; buffer[index+1] = 0; buffer[index+2] = 0
                }
            }
            let side = min(width, height)/2
            let x0 = (width-side)/2, y0 = (height-side)/2
            let gap = max(1, side/24)
            for y in 0..<side where abs(y-side/2) > gap {
                for x in 0..<side where abs(x-side/2) > gap {
                    let index = ((top+y0+y)*frameWidth+left+x0+x)*4
                    buffer[index] = 240; buffer[index+1] = 170; buffer[index+2] = 30
                }
            }
        }
        return output
    }
}
