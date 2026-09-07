import Testing
import Foundation
@testable import MDPreviewCore

private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    /// 返回 true 表示本次调用「抢到」了首次 resume
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

@Suite("FileMonitor 外部变更监听")
@MainActor
struct FileMonitorTests {

    private func tempFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdp-monitor-\(UUID().uuidString).md")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("外部写入触发 .modified")
    func detectsWrite() async throws {
        let url = try tempFile("initial")
        defer { try? FileManager.default.removeItem(at: url) }

        var monitor: FileMonitor?
        let guardBox = ResumeGuard()

        let event: FileMonitor.Event? = await withCheckedContinuation { cont in
            monitor = FileMonitor(url: url) { ev in
                if guardBox.claim() { cont.resume(returning: ev) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                try? "changed on disk".write(to: url, atomically: false, encoding: .utf8)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if guardBox.claim() { cont.resume(returning: nil) }
            }
        }
        monitor?.stop()
        #expect(event == .modified)
    }

    @Test("文件删除触发 .deleted")
    func detectsDelete() async throws {
        let url = try tempFile("initial")

        var monitor: FileMonitor?
        let guardBox = ResumeGuard()

        let event: FileMonitor.Event? = await withCheckedContinuation { cont in
            monitor = FileMonitor(url: url) { ev in
                if guardBox.claim() { cont.resume(returning: ev) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                try? FileManager.default.removeItem(at: url)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if guardBox.claim() { cont.resume(returning: nil) }
            }
        }
        monitor?.stop()
        #expect(event == .deleted)
    }

    @Test("readText 读回内容（含中文）")
    func readsText() throws {
        let url = try tempFile("hello 世界\n第二行")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileMonitor.readText(at: url) == "hello 世界\n第二行")
    }
}
