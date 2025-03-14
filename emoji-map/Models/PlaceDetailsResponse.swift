//
//  PlaceDetailsResponse.swift
//  emoji-map
//
//  Created by Enrique on 3/13/25.
//

import Foundation
import os.log

// Response structure for the place details API
struct PlaceDetailsResponse: Codable {
    let data: PlaceDetails
    let cacheHit: Bool
    let count: Int
    
    // Logger for debugging
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetailsResponse")
    
    // Custom decoding to handle potential issues
    init(from decoder: Decoder) throws {
        Self.logger.notice("Starting to decode PlaceDetailsResponse")
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            data = try container.decode(PlaceDetails.self, forKey: .data)
            cacheHit = try container.decodeIfPresent(Bool.self, forKey: .cacheHit) ?? false
            count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        } catch {
            Self.logger.error("Error decoding PlaceDetailsResponse: \(error.localizedDescription)")
            throw error
        }
    }
}

// Structure for place details
struct PlaceDetails: Codable {
    let name: String
    let reviews: [Review]?
    let rating: Double?
    let priceLevel: Int?
    let userRatingCount: Int?
    let openNow: Bool?
    let displayName: String?
    let primaryTypeDisplayName: String?
    let takeout: Bool?
    let delivery: Bool?
    let dineIn: Bool?
    let editorialSummary: String?
    let outdoorSeating: Bool?
    let liveMusic: Bool?
    let menuForChildren: Bool?
    let servesDessert: Bool?
    let servesCoffee: Bool?
    let goodForChildren: Bool?
    let goodForGroups: Bool?
    let allowsDogs: Bool?
    let restroom: Bool?
    let paymentOptions: PaymentOptions?
    let generativeSummary: String?
    let isFree: Bool?
    
    // Logger for debugging
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PlaceDetails")
    
    // Custom decoding to handle potential issues
    init(from decoder: Decoder) throws {
        Self.logger.notice("Starting to decode PlaceDetails")
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required field with fallback
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        
        // Optional fields
        do {
            reviews = try container.decodeIfPresent([Review].self, forKey: .reviews)
        } catch {
            Self.logger.error("Error decoding reviews: \(error.localizedDescription)")
            reviews = []
        }
        
        do {
            rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        } catch {
            Self.logger.error("Error decoding rating: \(error.localizedDescription)")
            // Try to decode as Int and convert to Double if that works
            if let intRating = try? container.decodeIfPresent(Int.self, forKey: .rating) {
                rating = Double(intRating)
            } else {
                rating = nil
            }
        }
        
        do {
            priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        } catch {
            Self.logger.error("Error decoding priceLevel: \(error.localizedDescription)")
            // Try to decode as String and convert to Int if that works
            if let stringPrice = try? container.decodeIfPresent(String.self, forKey: .priceLevel),
               let intPrice = Int(stringPrice) {
                priceLevel = intPrice
            } else {
                priceLevel = nil
            }
        }
        
        userRatingCount = try container.decodeIfPresent(Int.self, forKey: .userRatingCount)
        openNow = try container.decodeIfPresent(Bool.self, forKey: .openNow)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        primaryTypeDisplayName = try container.decodeIfPresent(String.self, forKey: .primaryTypeDisplayName)
        takeout = try container.decodeIfPresent(Bool.self, forKey: .takeout)
        delivery = try container.decodeIfPresent(Bool.self, forKey: .delivery)
        dineIn = try container.decodeIfPresent(Bool.self, forKey: .dineIn)
        editorialSummary = try container.decodeIfPresent(String.self, forKey: .editorialSummary)
        outdoorSeating = try container.decodeIfPresent(Bool.self, forKey: .outdoorSeating)
        liveMusic = try container.decodeIfPresent(Bool.self, forKey: .liveMusic)
        menuForChildren = try container.decodeIfPresent(Bool.self, forKey: .menuForChildren)
        servesDessert = try container.decodeIfPresent(Bool.self, forKey: .servesDessert)
        servesCoffee = try container.decodeIfPresent(Bool.self, forKey: .servesCoffee)
        goodForChildren = try container.decodeIfPresent(Bool.self, forKey: .goodForChildren)
        goodForGroups = try container.decodeIfPresent(Bool.self, forKey: .goodForGroups)
        allowsDogs = try container.decodeIfPresent(Bool.self, forKey: .allowsDogs)
        restroom = try container.decodeIfPresent(Bool.self, forKey: .restroom)
        
        do {
            paymentOptions = try container.decodeIfPresent(PaymentOptions.self, forKey: .paymentOptions)
        } catch {
            Self.logger.error("Error decoding paymentOptions: \(error.localizedDescription)")
            paymentOptions = nil
        }
        
        generativeSummary = try container.decodeIfPresent(String.self, forKey: .generativeSummary)
        isFree = try container.decodeIfPresent(Bool.self, forKey: .isFree)
    }
    
    // Review structure
    struct Review: Codable, Identifiable {
        let name: String
        let relativePublishTimeDescription: String
        let rating: Int
        let text: TextContent
        let originalText: TextContent?
        
        // Use the name as the ID
        var id: String { name }
        
        // Logger for debugging
        private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "Review")
        
        // Text content structure
        struct TextContent: Codable {
            var text: String
            let languageCode: String?
            
            // Logger for debugging
            private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "TextContent")
            
            // Custom decoding to handle potential missing fields
            init(from decoder: Decoder) throws {
                Self.logger.notice("Starting to decode TextContent")
                
                // Try to decode as a container first
                do {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
                    languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode)
                } catch {
                    Self.logger.error("Error decoding TextContent as container: \(error.localizedDescription)")
                    
                    // If that fails, try to decode as a string directly
                    do {
                        let singleValue = try decoder.singleValueContainer()
                        text = try singleValue.decode(String.self)
                        languageCode = nil
                    } catch {
                        Self.logger.error("Error decoding TextContent as string: \(error.localizedDescription)")
                        // Last resort fallback
                        text = ""
                        languageCode = nil
                    }
                }
            }
            
            // Manual initializer for creating instances directly
            init(text: String, languageCode: String? = nil) {
                self.text = text
                self.languageCode = languageCode
            }
            
            private enum CodingKeys: String, CodingKey {
                case text
                case languageCode
            }
        }
        
        // Custom decoding to handle potential missing fields
        init(from decoder: Decoder) throws {
            Self.logger.notice("Starting to decode Review")
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Required fields with fallbacks
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            relativePublishTimeDescription = try container.decodeIfPresent(String.self, forKey: .relativePublishTimeDescription) ?? ""
            
            // Handle rating with fallback
            do {
                rating = try container.decode(Int.self, forKey: .rating)
            } catch {
                Self.logger.error("Error decoding rating: \(error.localizedDescription)")
                // Try to decode as Double and convert to Int
                if let doubleRating = try? container.decode(Double.self, forKey: .rating) {
                    rating = Int(doubleRating)
                } else {
                    rating = 0
                }
            }
            
            // Handle text content with multiple possible formats
            do {
                text = try container.decode(TextContent.self, forKey: .text)
            } catch {
                Self.logger.error("Error decoding text: \(error.localizedDescription)")
                
                // Try alternative approaches
                if let textString = try? container.decode(String.self, forKey: .text) {
                    text = TextContent(text: textString)
                } else {
                    text = TextContent(text: "")
                }
            }
            
            // Handle optional originalText
            do {
                originalText = try container.decodeIfPresent(TextContent.self, forKey: .originalText)
            } catch {
                Self.logger.error("Error decoding originalText: \(error.localizedDescription)")
                originalText = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case name
            case relativePublishTimeDescription
            case rating
            case text
            case originalText
        }
        
        // Manual initializer for testing or creating reviews programmatically
        init(name: String, relativePublishTimeDescription: String, rating: Int, text: TextContent, originalText: TextContent? = nil) {
            self.name = name
            self.relativePublishTimeDescription = relativePublishTimeDescription
            self.rating = rating
            self.text = text
            self.originalText = originalText
        }
    }
    
    // Payment options structure
    struct PaymentOptions: Codable {
        let acceptsCreditCards: Bool?
        let acceptsDebitCards: Bool?
        let acceptsCashOnly: Bool?
        
        // Logger for debugging
        private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.emoji-map", category: "PaymentOptions")
        
        // Custom decoding to handle potential issues
        init(from decoder: Decoder) throws {
            Self.logger.notice("Starting to decode PaymentOptions")
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            acceptsCreditCards = try container.decodeIfPresent(Bool.self, forKey: .acceptsCreditCards)
            acceptsDebitCards = try container.decodeIfPresent(Bool.self, forKey: .acceptsDebitCards)
            acceptsCashOnly = try container.decodeIfPresent(Bool.self, forKey: .acceptsCashOnly)
        }
    }
} 
