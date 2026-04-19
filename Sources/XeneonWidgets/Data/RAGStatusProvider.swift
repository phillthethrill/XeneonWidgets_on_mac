import Foundation

enum RAGComponentStatus: Equatable {
    case checking
    case up(detail: String)
    case down(detail: String)
}

struct RAGComponentState: Identifiable {
    let id: String
    let name: String
    let icon: String
    var status: RAGComponentStatus = .checking
}

final class RAGStatusProvider: ObservableObject {
    @Published var ollama    = RAGComponentState(id: "ollama",    name: "Ollama",      icon: "brain")
    @Published var docling   = RAGComponentState(id: "docling",   name: "Docling",     icon: "doc.text.magnifyingglass")
    @Published var openWebUI = RAGComponentState(id: "openwebui", name: "Open WebUI",  icon: "globe")
    @Published var watcher   = RAGComponentState(id: "watcher",   name: "Watcher",     icon: "eye")

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.local.xeneon.rag", qos: .utility)
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        cfg.timeoutIntervalForResource = 5
        return URLSession(configuration: cfg)
    }()

    func startPolling() {
        poll()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 15, repeating: 15)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func poll() {
        checkOllama()
        checkDocling()
        checkOpenWebUI()
        checkWatcher()
    }

    // MARK: - Ollama (native, port 11434)

    private func checkOllama() {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return }
        session.dataTask(with: url) { [weak self] data, _, error in
            let status: RAGComponentStatus
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let n = models.count
                status = .up(detail: "\(n) model\(n == 1 ? "" : "s") loaded")
            } else {
                status = .down(detail: "unreachable")
            }
            DispatchQueue.main.async { self?.ollama.status = status }
        }.resume()
    }

    // MARK: - Docling (Docker, port 5001)

    private func checkDocling() {
        guard let url = URL(string: "http://localhost:5001/health") else { return }
        session.dataTask(with: url) { [weak self] _, response, _ in
            let status: RAGComponentStatus
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                status = .up(detail: "healthy")
            } else {
                status = .down(detail: "unreachable")
            }
            DispatchQueue.main.async { self?.docling.status = status }
        }.resume()
    }

    // MARK: - Open WebUI (Docker, port 3000)

    private func checkOpenWebUI() {
        guard let url = URL(string: "http://localhost:3000/health") else { return }
        session.dataTask(with: url) { [weak self] _, response, _ in
            let status: RAGComponentStatus
            if let http = response as? HTTPURLResponse, http.statusCode < 500 {
                status = .up(detail: "reachable")
            } else {
                status = .down(detail: "unreachable")
            }
            DispatchQueue.main.async { self?.openWebUI.status = status }
        }.resume()
    }

    // MARK: - Watcher (Docker container, no exposed port)

    private func checkWatcher() {
        guard let docker = dockerBinaryPath() else {
            DispatchQueue.main.async { self.watcher.status = .down(detail: "docker not found") }
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: docker)
        process.arguments = ["ps", "--filter", "name=rag-watcher", "--format", "{{.Status}}"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let status: RAGComponentStatus
            if raw.lowercased().hasPrefix("up") {
                status = .up(detail: raw)
            } else if raw.isEmpty {
                status = .down(detail: "container stopped")
            } else {
                status = .down(detail: raw)
            }
            DispatchQueue.main.async { self.watcher.status = status }
        } catch {
            DispatchQueue.main.async { self.watcher.status = .down(detail: error.localizedDescription) }
        }
    }

    private func dockerBinaryPath() -> String? {
        ["/usr/local/bin/docker", "/opt/homebrew/bin/docker", "/usr/bin/docker"]
            .first { FileManager.default.fileExists(atPath: $0) }
    }
}
