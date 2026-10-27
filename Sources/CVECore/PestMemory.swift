import Darwin
import Foundation

public struct PestMemorySnapshot: Sendable {
    public var availableBytes: UInt64
    public var residentBytes: UInt64
    public var physicalBytes: UInt64
    public var diskAvailableBytes: Int64?

    public init(
        availableBytes: UInt64,
        residentBytes: UInt64,
        physicalBytes: UInt64,
        diskAvailableBytes: Int64?
    ) {
        self.availableBytes = availableBytes
        self.residentBytes = residentBytes
        self.physicalBytes = physicalBytes
        self.diskAvailableBytes = diskAvailableBytes
    }
}

public struct PestResourceBudget: Sendable, Equatable {
    public var maxFiles: Int
    public var maxFileBytes: Int
    public var maxTotalBytes: Int
    public var maxChunkCharacters: Int
    public var maxRSSGrowthBytes: UInt64
    public var minimumAvailableBytes: UInt64
    public var maxLLMChunks: Int
    public var availableAtStart: UInt64
    public var diskAvailableAtStart: Int64?

    public init(
        maxFiles: Int,
        maxFileBytes: Int,
        maxTotalBytes: Int,
        maxChunkCharacters: Int,
        maxRSSGrowthBytes: UInt64,
        minimumAvailableBytes: UInt64,
        maxLLMChunks: Int,
        availableAtStart: UInt64,
        diskAvailableAtStart: Int64?
    ) {
        self.maxFiles = maxFiles
        self.maxFileBytes = maxFileBytes
        self.maxTotalBytes = maxTotalBytes
        self.maxChunkCharacters = maxChunkCharacters
        self.maxRSSGrowthBytes = maxRSSGrowthBytes
        self.minimumAvailableBytes = minimumAvailableBytes
        self.maxLLMChunks = maxLLMChunks
        self.availableAtStart = availableAtStart
        self.diskAvailableAtStart = diskAvailableAtStart
    }
}

public enum PestMemoryGuard {
    public static let minimumAvailableBytes: UInt64 = 192 * 1024 * 1024
    public static let minimumDiskBytes: Int64 = 64 * 1024 * 1024
    public static let hardRSSGrowthCap: UInt64 = 64 * 1024 * 1024
    public static let minimumRSSGrowth: UInt64 = 16 * 1024 * 1024

    public static func snapshot() -> PestMemorySnapshot {
        PestMemorySnapshot(
            availableBytes: availableMemory(),
            residentBytes: residentMemory(),
            physicalBytes: ProcessInfo.processInfo.physicalMemory,
            diskAvailableBytes: diskAvailable()
        )
    }

    public static func budget(for snapshot: PestMemorySnapshot) -> PestResourceBudget? {
        guard snapshot.availableBytes >= minimumAvailableBytes else { return nil }
        guard (snapshot.diskAvailableBytes ?? Int64.max) >= minimumDiskBytes else { return nil }

        let quarter = snapshot.availableBytes / 4
        let growth = max(minimumRSSGrowth, min(hardRSSGrowthCap, quarter))
        let fullRun = snapshot.availableBytes >= 512 * 1024 * 1024

        return PestResourceBudget(
            maxFiles: fullRun ? 64 : 32,
            maxFileBytes: fullRun ? 48_000 : 32_000,
            maxTotalBytes: fullRun ? 1_200_000 : 600_000,
            maxChunkCharacters: fullRun ? 42_000 : 24_000,
            maxRSSGrowthBytes: growth,
            minimumAvailableBytes: minimumAvailableBytes,
            maxLLMChunks: fullRun ? 8 : 4,
            availableAtStart: snapshot.availableBytes,
            diskAvailableAtStart: snapshot.diskAvailableBytes
        )
    }

    public static func pauseReason(
        baselineRSS: UInt64,
        budget: PestResourceBudget
    ) -> String? {
        let current = snapshot()
        if current.availableBytes < budget.minimumAvailableBytes {
            return "O Mac está com \(formatBytes(current.availableBytes)) de memória disponível; o mínimo seguro para o Pest é \(formatBytes(budget.minimumAvailableBytes))."
        }
        let growth = current.residentBytes > baselineRSS
            ? current.residentBytes - baselineRSS
            : 0
        if growth > budget.maxRSSGrowthBytes {
            return "O Pest chegou a \(formatBytes(growth)) de memória adicional, acima do limite de \(formatBytes(budget.maxRSSGrowthBytes))."
        }
        if let disk = current.diskAvailableBytes, disk < minimumDiskBytes {
            return "O disco está com apenas \(formatBytes(UInt64(max(disk, 0)))) livres; o mínimo para salvar o relatório é \(formatBytes(UInt64(minimumDiskBytes)))."
        }
        return nil
    }

    public static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(min(bytes, UInt64(Int64.max))))
    }

    private static func availableMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count + stats.inactive_count + stats.speculative_count)
        return free * page
    }

    private static func residentMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }

    private static func diskAvailable() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
