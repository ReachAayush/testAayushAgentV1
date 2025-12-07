# Spoonacular API Setup - Quick Start

## ✅ What's Been Done

1. ✅ Updated `ConfigurationService` to support Spoonacular API key
2. ✅ Updated `RestaurantDiscoveryService` to use Spoonacular API (with mock fallback)
3. ✅ Added Spoonacular response models for parsing API data
4. ✅ Wired into existing workflow - no changes needed to actions/views
5. ✅ Added API key placeholder to `AppConfig.plist`

## 🔑 Step 1: Add Your API Key

You have two options to add your Spoonacular API key:

### Option A: AppConfig.plist (Recommended for Development)

1. Open `AayushTestAppV1/AppConfig.plist`
2. Find the line: `<string>YOUR_SPOONACULAR_API_KEY_HERE</string>`
3. Replace `YOUR_SPOONACULAR_API_KEY_HERE` with your actual API key
4. Save the file

### Option B: Keychain (Recommended for Production)

The app will automatically check the Keychain if the API key isn't in AppConfig.plist. You can add it programmatically or through the settings UI (if you build one).

## 🧪 Step 2: Test It!

1. **Build and run the app**
2. **Go to Restaurant Reservation feature**
3. **Fill in your contact info** (if not already set up)
4. **Click "Find & Book Restaurant"**
5. **The app will now use Spoonacular API** to find real restaurants near your location!

## 📊 What to Expect

- **Real restaurant data** from Spoonacular
- **Actual locations** based on your current location
- **Real ratings and cuisine types**
- **Location-aware addresses** (Jersey City, Pittsburgh, etc.)

## 🔍 Debugging

If the API isn't working:

1. **Check the logs** - Look for Spoonacular API calls in the debug console
2. **Verify API key** - Make sure it's correctly set in AppConfig.plist
3. **Check quota** - Free tier is 150 points/day (each search costs 3 points = ~50 searches/day)
4. **Rate limits** - Free tier allows 60 requests/minute

### Common Issues

**"API quota exceeded" error:**
- You've used all 150 points for today
- Wait until midnight UTC (check your timezone offset)
- Or upgrade to a paid plan

**"Rate limit exceeded" error:**
- You're making requests too fast
- Free tier: 60 requests/minute
- Wait a few seconds between searches

**"Invalid API key" error:**
- Check that the API key in AppConfig.plist is correct
- Make sure there are no extra spaces or quotes

**Still seeing mock data:**
- The API key might not be loading correctly
- Check the logs for "Spoonacular API key not found"
- Verify the key is in AppConfig.plist or Keychain

## 🎯 Next Steps

Once you confirm it's working, you can:
1. Add caching to reduce API calls
2. Improve error messages for users
3. Add quota monitoring/warnings
4. Integrate OpenTable for actual reservations

## 📝 Notes

- The service **automatically falls back to mock data** if no API key is found (for development)
- All API calls are **logged** for debugging
- **Quota headers** are checked and logged
- The workflow is **fully integrated** - no changes needed to RestaurantReservationAction
