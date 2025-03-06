# Configuration Guide for Emoji Map

This document explains how to configure the Emoji Map application, particularly focusing on API keys and configuration files.

## Configuration Files

Emoji Map uses several configuration files to manage settings and API keys:

### 1. CustomInfo.plist

This is the main information property list file for the application. It contains:

- Standard iOS app configuration (bundle ID, version, etc.)
- Permission descriptions
- UI configuration
- **API Keys**: The `GooglePlacesAPIKey` is stored here as the primary source

Location: `emoji-map/CustomInfo.plist`

### 2. Config.plist

This is a secondary configuration file specifically for API keys and other sensitive information:

- Contains the `GooglePlacesAPIKey` as a backup source
- Used during development and as a fallback

Location: `emoji-map/Config.plist`

### 3. Info.plist (Legacy Support)

Some third-party SDKs (like Google Maps/Places) may look for API keys directly in a file named `Info.plist`. The app includes fallback logic to check this file if needed.

## API Key Configuration

### Google Places API Key

The app requires a Google Places API key to fetch restaurant data. The key is retrieved in the following order:

1. From `CustomInfo.plist` (primary source)
2. From `Config.plist` (secondary source)
3. From standard `Info.plist` (fallback for compatibility)
4. From the device keychain (for production)

If no key is found, the app falls back to mock data mode.

### Setting Up Your API Key

1. Obtain a Google Places API key from the [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Places API for your project
3. Add the key to your `CustomInfo.plist` file:

```xml
<key>GooglePlacesAPIKey</key>
<string>YOUR_API_KEY_HERE</string>
```

## Mock Data Mode

If no valid API key is found, the app automatically switches to mock data mode:

- A warning banner appears in the app
- Pre-defined sample data is used instead of API calls
- Useful for development and testing without API quota usage

## Security Considerations

For production builds:

1. The API key should be stored in the keychain rather than in plist files
2. Use the `Configuration.storeAPIKey(_:named:)` method to securely store keys
3. Consider implementing API key restrictions in the Google Cloud Console

## Troubleshooting

### API Key Not Found

If the app shows "API key not configured properly":

1. Verify the key exists in `CustomInfo.plist`
2. Check that the key name is exactly `GooglePlacesAPIKey`
3. Ensure the plist file is included in the "Copy Bundle Resources" build phase
4. Clean and rebuild the project

### Google SDK Issues

If the Google Places SDK cannot find the API key:

1. The SDK might be looking directly for `Info.plist` instead of `CustomInfo.plist`
2. Ensure your key is correctly set in `CustomInfo.plist`
3. The app's configuration system will handle finding the key in the correct location

## Environment Variables

For CI/CD pipelines, you can use environment variables:

```bash
export GOOGLE_PLACES_API_KEY="your-api-key-here"
```

Then modify your build script to inject this into the plist files during build time.
