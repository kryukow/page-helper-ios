import Foundation

enum Failure: Error { case message(String) }
@main struct StreamCoordinatorTests {
    static func main() async throws {
        let coordinator = SafariStreamCoordinator()
        try await coordinator.begin("one")
        try await coordinator.update("one", output: "[\"При")
        let partial = await coordinator.snapshot("one")
        precondition(partial["output"] as? String == "[\"При", "Partial words must be visible before completion")
        await coordinator.finish("one")
        let forgotten = await coordinator.snapshot("one")
        precondition(forgotten["pending"] as? Bool == true)
        await coordinator.cancel("cancelled-before-start")
        do { try await coordinator.begin("cancelled-before-start"); fatalError("Cancelled job restarted") } catch is CancellationError {}
        try await coordinator.begin("cancelled")
        let worker = Task<[String], Error> { try await Task.sleep(nanoseconds: 10_000_000_000); return [] }
        await coordinator.attach("cancelled", task: worker)
        await coordinator.cancel("cancelled")
        do { _ = try await worker.value; fatalError("Worker was not cancelled") } catch is CancellationError {}
        for id in ["a", "b", "c", "d"] { try await coordinator.begin(id) }
        do { try await coordinator.begin("e"); fatalError("Unbounded native jobs") } catch {}
        for id in ["a", "b", "c", "d"] { await coordinator.cancel(id) }
        print("PASS: in-memory partial output, cleanup, cancellation race, task cancellation, bounded jobs")
    }
}
