import Metal
import MetalPerformanceShaders
import Foundation

// GPU 壓力測試:連續大矩陣乘法 (FP32),預設 30 分鐘
let durationMinutes = CommandLine.arguments.count > 1 ? Double(CommandLine.arguments[1]) ?? 30 : 30
let N = 4096  // 矩陣大小 N x N

guard let device = MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue() else {
    fatalError("無法初始化 Metal 裝置")
}

print("GPU: \(device.name)")
print("測試時長: \(Int(durationMinutes)) 分鐘,矩陣大小: \(N)x\(N) FP32")
print(String(repeating: "-", count: 60))

let bytes = N * N * MemoryLayout<Float>.size
let desc = MPSMatrixDescriptor(rows: N, columns: N, rowBytes: N * MemoryLayout<Float>.size, dataType: .float32)

func makeMatrix() -> MPSMatrix {
    let buf = device.makeBuffer(length: bytes, options: .storageModePrivate)!
    return MPSMatrix(buffer: buf, descriptor: desc)
}

// 先用隨機資料初始化 A、B
let seedData = (0..<(N*N)).map { _ in Float.random(in: -1...1) }
let seedBuf = seedData.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: bytes, options: .storageModeShared)! }
let A = makeMatrix(), B = makeMatrix(), C = makeMatrix()
if let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
    blit.copy(from: seedBuf, sourceOffset: 0, to: A.data, destinationOffset: 0, size: bytes)
    blit.copy(from: seedBuf, sourceOffset: 0, to: B.data, destinationOffset: 0, size: bytes)
    blit.endEncoding(); cb.commit(); cb.waitUntilCompleted()
}

let matmul = MPSMatrixMultiplication(device: device, transposeLeft: false, transposeRight: false,
                                     resultRows: N, resultColumns: N, interiorColumns: N,
                                     alpha: 1e-6, beta: 0)  // alpha 縮小避免溢位

let flopsPerOp = 2.0 * Double(N) * Double(N) * Double(N)
let opsPerBuffer = 4     // 每個 command buffer 少量運算,避免 watchdog 誤殺
let buffersPerBatch = 15 // 每批 60 次乘法後回報一次
let start = Date()
let endTime = start.addingTimeInterval(durationMinutes * 60)
var totalOps = 0
var errorCount = 0

while Date() < endTime {
    let batchStart = Date()
    var batchOps = 0
    for _ in 0..<buffersPerBatch {
        guard let cb = queue.makeCommandBuffer() else { errorCount += 1; continue }
        for _ in 0..<opsPerBuffer {
            matmul.encode(commandBuffer: cb, leftMatrix: A, rightMatrix: B, resultMatrix: C)
        }
        cb.commit()
        cb.waitUntilCompleted()
        if cb.status == .error {
            errorCount += 1
            if errorCount <= 5 {
                print("⚠️  GPU 錯誤: \(cb.error?.localizedDescription ?? "unknown")")
            }
        }
        batchOps += opsPerBuffer
    }
    if errorCount > 20 {
        print("❌ GPU 錯誤超過 20 次,提前中止測試")
        break
    }
    totalOps += batchOps

    let batchSec = Date().timeIntervalSince(batchStart)
    let tflops = flopsPerOp * Double(batchOps) / batchSec / 1e12
    let elapsed = Date().timeIntervalSince(start)
    let remaining = max(0, durationMinutes * 60 - elapsed)
    print(String(format: "[%5.1f 分鐘] %.2f TFLOPS | 已完成 %d 次乘法 | 剩餘 %.1f 分鐘 | 錯誤 %d",
                 elapsed / 60, tflops, totalOps, remaining / 60, errorCount))
}

print(String(repeating: "-", count: 60))
print("✅ 測試完成!總共 \(totalOps) 次 \(N)x\(N) 矩陣乘法,GPU 錯誤次數: \(errorCount)")
print(errorCount == 0 ? "GPU 狀態看起來正常 🎉" : "⚠️  偵測到 \(errorCount) 次 GPU 錯誤,建議送回檢查")