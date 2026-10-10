import Foundation

// One long native request keeps the extension alive; short requests read its in-memory progress.
// Text and jobs are never written to disk or UserDefaults.
actor SafariStreamCoordinator {
    static let shared = SafariStreamCoordinator()
    private struct Job {
        var output = ""
        var updated = Date()
        var task: Task<[String], Error>?
    }
    private var jobs: [String: Job] = [:]
    private var cancelled: [String: Date] = [:]
    func begin(_ id: String) throws {
        let cutoff = Date().addingTimeInterval(-120)
        cancelled = cancelled.filter { $0.value >= cutoff }
        guard cancelled[id] == nil else { throw CancellationError() }
        for (key, job) in jobs where job.updated < cutoff { job.task?.cancel(); jobs.removeValue(forKey: key) }
        guard jobs[id] == nil, jobs.count < 4 else { throw Failure.message("Перевод занят. Попробуй через несколько секунд.") }
        jobs[id] = Job()
    }
    func attach(_ id: String, task: Task<[String], Error>) {
        guard var job = jobs[id] else { task.cancel(); return }
        job.task = task; jobs[id] = job
    }
    func update(_ id: String, output: String) throws {
        guard var job = jobs[id] else { throw CancellationError() }
        try Task.checkCancellation()
        job.output = output; job.updated = Date(); jobs[id] = job
    }
    func snapshot(_ id: String) -> [String: Any] {
        guard let job = jobs[id] else { return ["pending": true] }
        return ["output": job.output]
    }
    func cancel(_ id: String) {
        cancelled[id] = Date()
        jobs.removeValue(forKey: id)?.task?.cancel()
    }
    func finish(_ id: String) { jobs.removeValue(forKey: id) }
}
