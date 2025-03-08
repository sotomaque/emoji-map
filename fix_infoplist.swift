#!/usr/bin/env swift

import Foundation

// Path to the Xcode project file
let projectPath = "/Users/enrique/Desktop/emoji-map/ios/emoji-map.xcodeproj/project.pbxproj"

// Check if the project file exists
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: projectPath) {
    print("❌ Xcode project file not found at: \(projectPath)")
    exit(1)
}

// Read the project file
guard let projectContent = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
    print("❌ Failed to read project file")
    exit(1)
}

// Create a backup of the project file
let backupPath = "\(projectPath).backup"
try? FileManager.default.removeItem(atPath: backupPath)
try? FileManager.default.copyItem(atPath: projectPath, toPath: backupPath)

// Simple approach: Remove the Info.plist from the Copy Bundle Resources phase
let infoPlistPattern = "emoji-mapTests/Info.plist in Copy Bundle Resources"
let modifiedContent = projectContent.replacingOccurrences(of: infoPlistPattern, with: "/* Info.plist removed to avoid duplicate */")

// Write the modified content back to the project file
do {
    try modifiedContent.write(toFile: projectPath, atomically: true, encoding: .utf8)
    print("✅ Successfully updated the project file")
} catch {
    print("❌ Failed to write modified project file: \(error)")
    exit(1)
}

print("🔔 Please open the project in Xcode and build it to verify the changes") 