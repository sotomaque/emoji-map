//
//  CategoryMappings.swift
//  emoji-map
//
//  Created by Enrique on 3/10/25.
//

import Foundation
import os.log

/// Category mapping for places
///
/// This map defines categories for places with associated emojis and keys.
/// Used for categorizing and displaying places on the map and in search results.
///
/// Each category has:
/// @property {Int} key - Unique identifier for the category
/// @property {String} emoji - Emoji representation of the category
struct CategoryMappings {
    // Logger
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "CategoryMappings")
    
    // Mapping from emoji to key
    static let emojiToKey: [String: Int] = [
        "🍕": 1,
        "🍺": 2,
        "🍣": 3,
        "☕️": 4,  // Coffee with variation selector
        "☕": 4,   // Coffee without variation selector (U+2615)
        "🍔": 5,
        "🌮": 6,
        "🍜": 7,
        "🥗": 8,
        "🍦": 9,
        "🍷": 10,
        "🍲": 11,
        "🥪": 12,
        "🍝": 13,
        "🥩": 14,
        "🍗": 15,
        "🍤": 16,
        "🍛": 17,
        "🥘": 18,
        "🍱": 19,
        "🥟": 20,
        "🧆": 21,
        "🥐": 22,
        "🍨": 23,
        "🍹": 24,
        "🍽️": 25,
        "🍽": 25   // Also support without variation selector
    ]
    
    // Mapping from key to emoji - standardize on the variant with variation selectors if applicable
    static let keyToEmoji: [Int: String] = [
        1: "🍕",
        2: "🍺",
        3: "🍣",
        4: "☕️",
        5: "🍔",
        6: "🌮",
        7: "🍜",
        8: "🥗",
        9: "🍦",
        10: "🍷",
        11: "🍲",
        12: "🥪",
        13: "🍝",
        14: "🥩",
        15: "🍗",
        16: "🍤",
        17: "🍛",
        18: "🥘",
        19: "🍱",
        20: "🥟",
        21: "🧆",
        22: "🥐",
        23: "🍨",
        24: "🍹",
        25: "🍽️"
    ]
    
    // Helper mapping to normalize emoji variants
    private static let normalizedEmojis: [String: String] = [
        "☕": "☕️",   // Map coffee without variation selector to with variation selector
        "🍽": "🍽️"    // Same for plate with utensils
    ]
    
    /// Get all available emoji keys
    static var allEmojis: [String] {
        return Array(Set(emojiToKey.keys))  // Use Set to eliminate duplicates
    }
    
    /// Get the key for a given emoji
    static func getKeyForEmoji(_ emoji: String) -> Int? {
        // First try direct lookup
        if let key = emojiToKey[emoji] {
            return key
        }
        
        // If that fails, try normalizing the emoji and look up again
        if let normalized = normalizedEmojis[emoji] {
            return emojiToKey[normalized]
        }
        
        return nil
    }
    
    /// Get the emoji for a given key
    static func getEmojiForKey(_ key: Int) -> String? {
        return keyToEmoji[key]
    }
    
    /// Get the base emoji character without variation selectors
    private static func normalizeEmoji(_ emoji: String) -> String {
        // For now, a simple lookup approach
        if emoji == "☕️" {
            return "☕"
        }
        if emoji == "🍽️" {
            return "🍽"
        }
        return emoji
    }
    
    /// Check if a place emoji string contains any of the selected category emojis
    static func placeContainsSelectedCategories(placeEmoji: String, selectedCategoryKeys: Set<Int>) -> Bool {
        // Special case for coffee emoji (☕/☕️) which is key 4
        if selectedCategoryKeys.contains(4) && (placeEmoji.contains("☕") || placeEmoji.contains("☕️")) {
            return true
        }
        
        let categoryEmojis = selectedCategoryKeys.compactMap { getEmojiForKey($0) }
        
        // First check if the place emoji contains any of the category emojis directly
        for categoryEmoji in categoryEmojis {
            if placeEmoji.contains(categoryEmoji) {
                return true
            }
        }
        
        // Then, check each character in the place emoji
        for character in placeEmoji {
            let singleEmoji = String(character)
            
            if let key = getKeyForEmoji(singleEmoji) {
                if selectedCategoryKeys.contains(key) {
                    return true
                }
            } else {
                // Special handling for coffee emoji (☕/☕️)
                if selectedCategoryKeys.contains(4) && (singleEmoji == "☕" || singleEmoji == "☕️") {
                    return true
                }
            }
        }
        
        // Also try checking for compound emoji which might have variation selectors
        for categoryKey in selectedCategoryKeys {
            if let categoryEmoji = getEmojiForKey(categoryKey) {
                // Try both with and without the variation selector
                let normalizedCategoryEmoji = normalizeEmoji(categoryEmoji)
                
                if placeEmoji.contains(categoryEmoji) || placeEmoji.contains(normalizedCategoryEmoji) {
                    logger.notice("🔍   ✅ Found matching category \(categoryKey) using normalized string contains")
                    return true
                } else {
                    logger.notice("🔍   ❌ Category \(categoryKey) not found using normalized string contains")
                }
            }
        }
        
        logger.notice("🔍 ❌ No matching categories found")
        return false
    }
    
    /// Get all category keys that match any emoji in the given string
    static func getCategoryKeysFromEmojiString(_ emojiString: String) -> Set<Int> {
        var keys = Set<Int>()
        
        for character in emojiString {
            let singleEmoji = String(character)
            if let key = getKeyForEmoji(singleEmoji) {
                keys.insert(key)
            }
        }
        
        // Special handling for coffee emoji (☕/☕️)
        if emojiString.contains("☕") || emojiString.contains("☕️") {
            keys.insert(4)  // Add coffee key
        }
        
        return keys
    }
} 
