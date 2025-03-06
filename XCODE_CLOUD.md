# Setting Up Xcode Cloud for Emoji Map

This guide explains how to set up Xcode Cloud to build and deploy Emoji Map with the required API keys.

## Environment Variables

Emoji Map requires the following environment variables to be set in Xcode Cloud:

### Required Variables

- `GOOGLE_PLACES_API_KEY`: Your Google Places API key

## Setting Up Environment Variables in Xcode Cloud

1. Go to App Store Connect (https://appstoreconnect.apple.com/)
2. Navigate to your app
3. Select "Xcode Cloud" from the sidebar
4. Select your workflow
5. Click "Edit" in the top right corner
6. Scroll down to the "Environment Variables" section
7. Click "Add Variable"
8. Enter the following:
   - Name: `GOOGLE_PLACES_API_KEY`
   - Value: Your actual Google Places API key
   - Check "Secret" to keep the value hidden
9. Click "Save"

## Build Scripts

The project includes a build script (`include_env.sh`) that handles environment variables in Xcode Cloud. This script:

1. Detects when running in Xcode Cloud
2. Reads the `GOOGLE_PLACES_API_KEY` environment variable
3. Creates a `.env` file in the app bundle with the API key

## Troubleshooting

### Build Failures

If your build fails with a message like:

```
Command PhaseScriptExecution failed with a nonzero exit code
```

Check the following:

1. Make sure the `include_env.sh` script is added as a Run Script build phase in Xcode
2. Ensure the script has execute permissions (`chmod +x include_env.sh`)
3. Verify that the environment variables are correctly set in Xcode Cloud

### Mock Data in TestFlight Builds

If your TestFlight builds are showing mock data:

1. Check that the `GOOGLE_PLACES_API_KEY` environment variable is set in Xcode Cloud
2. Verify that the value is correct
3. Check the build logs to see if the script is running correctly

## Viewing Build Logs

To view detailed build logs:

1. Go to App Store Connect
2. Navigate to your app
3. Select "Xcode Cloud" from the sidebar
4. Select the build you want to inspect
5. Click on "Build Logs"
6. Look for output from the `include_env.sh` script

## Testing Locally

To test the Xcode Cloud setup locally:

1. Set the `CI_XCODE_CLOUD` environment variable in your Xcode scheme
2. Set the `GOOGLE_PLACES_API_KEY` environment variable in your Xcode scheme
3. Build and run the app

This will simulate the Xcode Cloud environment and help you debug any issues.
