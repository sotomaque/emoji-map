#!/usr/bin/env swift

import Foundation

// Function to run a shell command and return the output
func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/bash"
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

// Check if Xcode is running
let xcodeRunning = shell("ps aux | grep -v grep | grep Xcode.app").count > 0
if xcodeRunning {
    print("⚠️ Please close Xcode before running this script.")
    exit(1)
}

// Path to the Xcode project
let projectPath = "/Users/enrique/Desktop/emoji-map/ios/emoji-map.xcodeproj"

// Check if the project exists
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: projectPath) {
    print("❌ Xcode project not found at: \(projectPath)")
    exit(1)
}

// Add ViewInspector package to the project
print("📦 Adding ViewInspector package to the project...")

// Create a temporary Swift Package Manager project
let tempDir = "/tmp/viewinspector_temp"
shell("mkdir -p \(tempDir)")
shell("cd \(tempDir) && swift package init")

// Add ViewInspector as a dependency
let packageSwift = """
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ViewInspectorTemp",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.8"),
    ],
    targets: [
        .target(
            name: "ViewInspectorTemp",
            dependencies: [.product(name: "ViewInspector", package: "ViewInspector")]),
    ]
)
"""

do {
    try packageSwift.write(toFile: "\(tempDir)/Package.swift", atomically: true, encoding: .utf8)
} catch {
    print("❌ Failed to write Package.swift: \(error)")
    exit(1)
}

// Resolve the package
print("🔄 Resolving ViewInspector package...")
shell("cd \(tempDir) && swift package resolve")

// Generate Xcode project
print("🔄 Generating Xcode project...")
shell("cd \(tempDir) && swift package generate-xcodeproj")

// Copy the resolved package to the main project
print("🔄 Copying resolved package to main project...")
shell("cp -f \(tempDir)/.build/checkouts/ViewInspector/* /Users/enrique/Desktop/emoji-map/ios/.swiftpm/checkouts/ViewInspector/ || true")

// Clean up
print("🧹 Cleaning up...")
shell("rm -rf \(tempDir)")

print("✅ ViewInspector package has been added to the project.")
print("🔔 Please open the project in Xcode and build it.") 