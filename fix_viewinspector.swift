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

// Check if ViewInspector is already in the project
if projectContent.contains("ViewInspector") {
    print("✅ ViewInspector is already in the project")
    
    // Check if it's linked to the test target
    if projectContent.contains("emoji-mapTests") && projectContent.contains("ViewInspector") {
        print("✅ ViewInspector is already linked to the test target")
        
        // Create a backup of the project file
        let backupPath = "\(projectPath).backup"
        try? FileManager.default.removeItem(atPath: backupPath)
        try? FileManager.default.copyItem(atPath: projectPath, toPath: backupPath)
        
        // Modify the project file to ensure ViewInspector is linked to the test target
        var modifiedContent = projectContent
        
        // Find the test target section
        if let testTargetRange = projectContent.range(of: "/* emoji-mapTests */ = {") {
            let testTargetSection = projectContent[testTargetRange.lowerBound...]
            
            // Find the dependencies section
            if let dependenciesRange = testTargetSection.range(of: "dependencies = (") {
                let dependenciesSection = testTargetSection[dependenciesRange.lowerBound...]
                
                // Check if ViewInspector is already in the dependencies
                if !dependenciesSection.contains("/* ViewInspector */") {
                    // Find the end of the dependencies section
                    if let endDependenciesRange = dependenciesSection.range(of: ");") {
                        // Insert ViewInspector dependency
                        let insertPoint = dependenciesSection.distance(from: dependenciesSection.startIndex, to: endDependenciesRange.lowerBound)
                        let insertIndex = projectContent.index(testTargetRange.lowerBound, offsetBy: dependenciesSection.distance(from: testTargetSection.startIndex, to: dependenciesSection.startIndex) + insertPoint)
                        
                        modifiedContent.insert(contentsOf: "\n\t\t\t\tCD9A120A2D7836EC0023EDF2 /* ViewInspector */,", at: insertIndex)
                        
                        // Write the modified content back to the project file
                        do {
                            try modifiedContent.write(toFile: projectPath, atomically: true, encoding: .utf8)
                            print("✅ Added ViewInspector dependency to the test target")
                        } catch {
                            print("❌ Failed to write modified project file: \(error)")
                            exit(1)
                        }
                    }
                } else {
                    print("✅ ViewInspector is already in the test target dependencies")
                }
            }
        }
    } else {
        print("⚠️ ViewInspector is in the project but may not be linked to the test target")
        print("Please follow the instructions in ViewInspectorSetup.md to link it manually")
    }
} else {
    print("⚠️ ViewInspector is not in the project")
    print("Please follow the instructions in ViewInspectorSetup.md to add it manually")
}

print("🔔 Please open the project in Xcode and build it to verify the changes") 