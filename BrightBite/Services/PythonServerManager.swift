//
//  PythonServerManager.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/27/25.
//

import Foundation
import Combine

#if canImport(Darwin)
import Darwin
#endif

class PythonServerManager: ObservableObject {
    static let shared = PythonServerManager()

    @Published var isServerRunning = false
    @Published var serverURL: String?
    @Published var serverStatus: ServerStatus = .stopped
    @Published var lastError: String?

    private var healthCheckTimer: Timer?
    private var startupAttempts = 0
    private let maxStartupAttempts = 3

    enum ServerStatus {
        case stopped
        case starting
        case running
        case error
    }

    private init() {
        
        checkServerHealth()
    }

    

    func ensureServerRunning() async throws {
        #if targetEnvironment(simulator)
        
        if isServerRunning {
            return
        }

        try await startServer()
        try await waitForServerReady(timeout: 30)
        #else
        
        print("📱 Running on iOS device - checking for server on Mac...")

        if await performHealthCheck() {
            await MainActor.run {
                self.isServerRunning = true
                self.serverStatus = .running
            }
            print("✅ Connected to server on Mac")
            return
        } else {
            await MainActor.run {
                self.serverStatus = .error
                self.lastError = "Cannot reach Python server. Please start it on your Mac:\ncd python_backend && ./start_server.sh"
            }
            throw ServerError.startupFailed("Server not reachable from iOS device")
        }
        #endif
    }

    func startServer() async throws {
        guard startupAttempts < maxStartupAttempts else {
            throw ServerError.maxAttemptsReached
        }

        startupAttempts += 1

        await MainActor.run {
            self.serverStatus = .starting
            self.lastError = nil
        }

        print("🚀 Starting Python backend server...")

        
        guard let projectPath = getProjectPath() else {
            throw ServerError.projectPathNotFound
        }

        let pythonBackendPath = projectPath + "/python_backend"
        let startScriptPath = pythonBackendPath + "/start_server.sh"

        
        if !FileManager.default.fileExists(atPath: startScriptPath) {
            throw ServerError.startScriptNotFound
        }

        
        #if os(macOS)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [startScriptPath]
        task.currentDirectoryURL = URL(fileURLWithPath: pythonBackendPath)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            if let output = String(data: outputData, encoding: .utf8) {
                print("Server start output: \(output)")

                
                if let ipMatch = output.range(of: #"http://[\d\.]+:8000"#, options: .regularExpression) {
                    let url = String(output[ipMatch])
                    await MainActor.run {
                        self.serverURL = url
                    }
                }
            }

            if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                print("Server start error: \(error)")
                await MainActor.run {
                    self.lastError = error
                }
            }

            if task.terminationStatus == 0 {
                print("✅ Server start script completed successfully")
                
                startHealthCheckMonitoring()
            } else {
                throw ServerError.startupFailed("Process exited with status \(task.terminationStatus)")
            }

        } catch {
            await MainActor.run {
                self.serverStatus = .error
                self.lastError = error.localizedDescription
            }
            throw ServerError.startupFailed(error.localizedDescription)
        }
        #else
        
        
        await MainActor.run {
            self.serverStatus = .error
            self.lastError = "Python server must be started manually on iOS device. Please run the server on your Mac and ensure the iOS device is on the same network."
        }
        print("⚠️ Cannot start Python server on iOS device automatically")
        print("📱 Please start the server manually on your Mac:")
        print("   cd '\(pythonBackendPath)' && ./start_server.sh")
        throw ServerError.startupFailed("Cannot spawn processes on iOS - please start server manually on Mac")
        #endif
    }

    func stopServer() async {
        print("🛑 Stopping Python backend server...")

        #if os(macOS)
        guard let projectPath = getProjectPath() else {
            print("❌ Could not find project path")
            return
        }

        let pythonBackendPath = projectPath + "/python_backend"
        let stopScriptPath = pythonBackendPath + "/stop_server.sh"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [stopScriptPath]
        task.currentDirectoryURL = URL(fileURLWithPath: pythonBackendPath)

        do {
            try task.run()
            task.waitUntilExit()

            await MainActor.run {
                self.isServerRunning = false
                self.serverStatus = .stopped
            }

            stopHealthCheckMonitoring()

            print("✅ Server stopped")
        } catch {
            print("❌ Failed to stop server: \(error)")
        }
        #else
        print("⚠️ Cannot stop server from iOS device")
        print("📱 Please stop the server manually on your Mac:")
        print("   cd python_backend && ./stop_server.sh")

        await MainActor.run {
            self.isServerRunning = false
            self.serverStatus = .stopped
        }
        stopHealthCheckMonitoring()
        #endif
    }

    

    func checkServerHealth() {
        Task {
            let isHealthy = await performHealthCheck()

            await MainActor.run {
                self.isServerRunning = isHealthy
                self.serverStatus = isHealthy ? .running : .stopped
            }
        }
    }

    private func performHealthCheck() async -> Bool {
        
        let testURL: String

        #if targetEnvironment(simulator)
        
        let localIP = getLocalIPAddress()
        testURL = "http://\(localIP):8000/health"
        #else
        
        testURL = "http://192.168.1.202:8000/health"
        #endif

        guard let url = URL(string: testURL) else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200

                if isHealthy {
                    let serverIP = testURL.replacingOccurrences(of: "/health", with: "")
                    await MainActor.run {
                        self.serverURL = serverIP
                    }
                    print("✅ Server health check passed: \(serverIP)")
                }

                return isHealthy
            }

            return false
        } catch {
            print("❌ Health check failed: \(error.localizedDescription)")
            return false
        }
    }

    private func waitForServerReady(timeout: TimeInterval) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if await performHealthCheck() {
                await MainActor.run {
                    self.isServerRunning = true
                    self.serverStatus = .running
                    self.startupAttempts = 0
                }
                print("✅ Server is ready!")
                return
            }

            try await Task.sleep(nanoseconds: 1_000_000_000) 
        }

        throw ServerError.timeout
    }

    private func startHealthCheckMonitoring() {
        stopHealthCheckMonitoring()

        DispatchQueue.main.async {
            self.healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.checkServerHealth()
            }
        }
    }

    private func stopHealthCheckMonitoring() {
        DispatchQueue.main.async {
            self.healthCheckTimer?.invalidate()
            self.healthCheckTimer = nil
        }
    }

    

    private func getProjectPath() -> String? {
        
        print("🔍 Searching for project path...")

        
        if let projectPath = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            print("✅ Found PROJECT_DIR environment variable: \(projectPath)")
            if FileManager.default.fileExists(atPath: projectPath + "/python_backend") {
                return projectPath
            } else {
                print("⚠️ PROJECT_DIR set but python_backend folder not found at: \(projectPath)")
            }
        } else {
            print("⚠️ PROJECT_DIR environment variable not set")
        }

        
        let possiblePaths = [
            "/Users/tuandnguyen/Desktop/Ben's Dev./BrightBite",
            "/Users/tuandnguyen/Desktop/BrightBite",
            NSHomeDirectory() + "/Desktop/Ben's Dev./BrightBite",
            NSHomeDirectory() + "/Desktop/BrightBite"
        ]

        for path in possiblePaths {
            print("🔍 Checking path: \(path)")
            if FileManager.default.fileExists(atPath: path + "/python_backend") {
                print("✅ Found project at: \(path)")
                return path
            }
        }

        
        if let bundlePath = Bundle.main.bundlePath as String? {
            print("🔍 Bundle path: \(bundlePath)")
            let components = bundlePath.components(separatedBy: "/")

            
            if let projectIndex = components.firstIndex(where: { $0.contains("BrightBite") && !$0.contains(".app") }) {
                let projectComponents = components[0...projectIndex]
                let path = "/" + projectComponents.dropFirst().joined(separator: "/")
                print("🔍 Derived path from bundle: \(path)")
                if FileManager.default.fileExists(atPath: path + "/python_backend") {
                    print("✅ Found project via bundle path: \(path)")
                    return path
                }
            }
        }

        
        var currentPath = FileManager.default.currentDirectoryPath
        print("🔍 Current directory: \(currentPath)")

        for _ in 0..<5 {  
            if FileManager.default.fileExists(atPath: currentPath + "/python_backend") {
                print("✅ Found project in current/parent directory: \(currentPath)")
                return currentPath
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }

        print("❌ Could not find project path")
        return nil
    }

    private func getLocalIPAddress() -> String {
        
        

        var address: String = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" { 
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return address
    }
}


enum ServerError: LocalizedError {
    case projectPathNotFound
    case startScriptNotFound
    case startupFailed(String)
    case timeout
    case maxAttemptsReached

    var errorDescription: String? {
        switch self {
        case .projectPathNotFound:
            return "Could not locate BrightBite project directory"
        case .startScriptNotFound:
            return "Python server start script not found"
        case .startupFailed(let message):
            return "Server startup failed: \(message)"
        case .timeout:
            return "Server failed to start within timeout period"
        case .maxAttemptsReached:
            return "Maximum server startup attempts reached"
        }
    }
}
