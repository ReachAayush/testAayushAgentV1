# Spoonacular API Integration Guide

This guide explains how to integrate the Spoonacular Food API for restaurant discovery in the restaurant reservation workflow.

## Why Spoonacular?

- ✅ **Free tier available**: 150 points/day, 60 requests/minute
- ✅ **Restaurant search endpoint**: Built-in support for searching restaurants by location
- ✅ **Rich data**: Ratings, cuisines, hours, contact info
- ✅ **Easy authentication**: Simple API key in query params or header

## API Overview

### Restaurant Search Endpoint

**Endpoint:** `GET https://api.spoonacular.com/food/restaurants/search`

**Documentation:** https://spoonacular.com/food-api/docs#Search-Restaurants

**Cost:** 3 points per request

**Rate Limits (Free Tier):**
- 60 requests per minute
- 150 points per day (resets at midnight UTC)

## Implementation Steps

### 1. Get API Key

1. Sign up at https://spoonacular.com/food-api
2. Get your free API key from the dashboard
3. Add it to `ConfigurationService`

### 2. Update RestaurantDiscoveryService

Replace the mock implementation with real Spoonacular API calls:

```swift
func searchRestaurants(
    near location: CLLocation,
    query: String? = nil,
    radius: Int = 5000,
    limit: Int = 10
) async throws -> [Restaurant] {
    let apiKey = configService.spoonacularApiKey
    guard !apiKey.isEmpty else {
        throw AppError.missingConfiguration(key: "SPOONACULAR_API_KEY")
    }
    
    // Convert radius from meters to miles (Spoonacular uses miles)
    let radiusMiles = Double(radius) / 1609.34
    
    // Build URL with parameters
    var components = URLComponents(string: "https://api.spoonacular.com/food/restaurants/search")!
    var queryItems: [URLQueryItem] = [
        URLQueryItem(name: "lat", value: "\(location.coordinate.latitude)"),
        URLQueryItem(name: "lng", value: "\(location.coordinate.longitude)"),
        URLQueryItem(name: "distance", value: "\(radiusMiles)"),
        URLQueryItem(name: "sort", value: "rating"), // Sort by rating
        URLQueryItem(name: "apiKey", value: apiKey)
    ]
    
    // Add query if provided (e.g., "vegetarian")
    if let query = query, !query.isEmpty {
        queryItems.append(URLQueryItem(name: "query", value: query))
        // Also try cuisine filter if query contains "vegetarian"
        if query.lowercased().contains("vegetarian") {
            // Note: Spoonacular may not have "vegetarian" as a cuisine
            // But we can filter results after receiving them
        }
    }
    
    components.queryItems = queryItems
    
    guard let url = components.url else {
        throw AppError.invalidConfiguration(key: "API_URL", value: nil)
    }
    
    // Make request
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    let (data, response) = try await session.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AppError.invalidResponse(underlying: nil)
    }
    
    // Check quota headers
    if let quotaLeftHeader = httpResponse.value(forHTTPHeaderField: "X-API-Quota-Left"),
       let quotaLeft = Int(quotaLeftHeader), quotaLeft < 3 {
        logger.warning("Spoonacular API quota running low: \(quotaLeft) points remaining", category: .restaurant)
    }
    
    guard (200..<300).contains(httpResponse.statusCode) else {
        if httpResponse.statusCode == 402 {
            throw AppError.actionFailed(
                action: "restaurant_search",
                reason: "API quota exceeded. Please try again tomorrow.",
                underlying: nil
            )
        } else if httpResponse.statusCode == 429 {
            throw AppError.actionFailed(
                action: "restaurant_search",
                reason: "Rate limit exceeded. Please wait a moment.",
                underlying: nil
            )
        }
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AppError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
    }
    
    // Parse response
    let decoder = JSONDecoder()
    let spoonacularResponse = try decoder.decode(SpoonacularRestaurantSearchResponse.self, from: data)
    
    // Filter for vegetarian-friendly restaurants if query contains "vegetarian"
    let filteredRestaurants = spoonacularResponse.restaurants.filter { restaurant in
        if let query = query, query.lowercased().contains("vegetarian") {
            // Check if cuisine array contains vegetarian-related terms
            let hasVegetarian = restaurant.cuisines.contains { cuisine in
                cuisine.lowercased().contains("vegetarian") ||
                cuisine.lowercased().contains("vegan") ||
                cuisine.lowercased().contains("plant")
            }
            return hasVegetarian || restaurant.name.lowercased().contains("vegetarian")
        }
        return true
    }
    
    // Map to our Restaurant model
    let restaurants = Array(filteredRestaurants.prefix(limit)).map { spoonRestaurant in
        Restaurant(
            id: spoonRestaurant._id,
            name: spoonRestaurant.name,
            cuisine: spoonRestaurant.cuisines.joined(separator: ", "),
            rating: spoonRestaurant.weighted_rating_value,
            priceLevel: String(repeating: "$", count: spoonRestaurant.dollar_signs),
            address: formatAddress(spoonRestaurant.address),
            phone: formatPhone(spoonRestaurant.phone_number),
            isVegetarianFriendly: spoonRestaurant.cuisines.contains { $0.lowercased().contains("vegetarian") || $0.lowercased().contains("vegan") },
            vegetarianOptionsCount: estimateVegetarianOptions(from: spoonRestaurant.cuisines),
            reservationProvider: determineReservationProvider(from: spoonRestaurant),
            coordinates: CLLocation(
                latitude: spoonRestaurant.address.lat,
                longitude: spoonRestaurant.address.lon
            )
        )
    }
    
    return restaurants
}

// Helper function to format address
private func formatAddress(_ addr: SpoonacularAddress) -> String {
    var components: [String] = []
    if !addr.street_addr.isEmpty { components.append(addr.street_addr) }
    components.append("\(addr.city), \(addr.state) \(addr.zipcode)")
    return components.joined(separator: ", ")
}

// Helper function to format phone
private func formatPhone(_ number: Int) -> String {
    let phoneString = String(number)
    // Format as US phone number (adjust for international if needed)
    if phoneString.count == 11 && phoneString.hasPrefix("1") {
        let areaCode = phoneString.dropFirst().prefix(3)
        let exchange = phoneString.dropFirst(4).prefix(3)
        let number = phoneString.dropFirst(7)
        return "+1-\(areaCode)-\(exchange)-\(number)"
    }
    return "+\(phoneString)"
}

// Estimate vegetarian options count based on cuisines
private func estimateVegetarianOptions(from cuisines: [String]) -> Int {
    let vegetarianKeywords = ["vegetarian", "vegan", "plant", "organic", "healthy"]
    let hasVegetarianFocus = cuisines.contains { cuisine in
        vegetarianKeywords.contains { keyword in
            cuisine.lowercased().contains(keyword)
        }
    }
    return hasVegetarianFocus ? 15 : 8 // Rough estimate
}

// Determine reservation provider (check if restaurant supports OpenTable/Rezzy)
private func determineReservationProvider(from restaurant: SpoonacularRestaurant) -> String {
    // Spoonacular doesn't provide reservation provider info directly
    // We'll default to OpenTable and let the reservation service handle fallback
    return "OpenTable"
}
```

### 3. Add Response Models

Add these models to parse Spoonacular's response:

```swift
struct SpoonacularRestaurantSearchResponse: Codable {
    let restaurants: [SpoonacularRestaurant]
}

struct SpoonacularRestaurant: Codable {
    let _id: String
    let name: String
    let phone_number: Int
    let address: SpoonacularAddress
    let type: String
    let description: String?
    let local_hours: SpoonacularHours?
    let cuisines: [String]
    let food_photos: [String]?
    let logo_photos: [String]?
    let dollar_signs: Int
    let pickup_enabled: Bool
    let delivery_enabled: Bool
    let is_open: Bool
    let offers_first_party_delivery: Bool
    let offers_third_party_delivery: Bool
    let miles: Double?
    let weighted_rating_value: Double
    let aggregated_rating_count: Int
}

struct SpoonacularAddress: Codable {
    let street_addr: String
    let city: String
    let state: String
    let zipcode: String
    let country: String
    let lat: Double
    let lon: Double
    let street_addr_2: String?
    let latitude: Double
    let longitude: Double
}

struct SpoonacularHours: Codable {
    let operational: [String: String]?
    let delivery: [String: String]?
    let pickup: [String: String]?
    let dine_in: [String: String]?
}
```

### 4. Add API Key to Configuration

Update `ConfigurationService.swift`:

```swift
enum ConfigKey: String, CaseIterable {
    // ... existing keys
    case spoonacularApiKey = "SPOONACULAR_API_KEY"
}

extension ConfigurationService {
    var spoonacularApiKey: String {
        get { get(.spoonacularApiKey) ?? "" }
        set { try? set(newValue, forKey: .spoonacularApiKey) }
    }
}
```

Add to `AppConfig.plist`:

```xml
<key>SPOONACULAR_API_KEY</key>
<string>YOUR_API_KEY_HERE</string>
```

## Error Handling

### Quota Exceeded (402)
- Check `X-API-Quota-Left` header before making requests
- Show user-friendly message: "Daily API limit reached. Try again tomorrow."
- Consider implementing request caching to reduce API calls

### Rate Limit (429)
- Implement exponential backoff
- Show message: "Too many requests. Please wait a moment."
- Cache recent searches for 5-10 minutes

### Invalid Location
- Validate coordinates before making request
- Handle cases where no restaurants are found

## Best Practices

1. **Cache Results**: Store search results for 5-10 minutes to avoid redundant API calls
2. **Check Quota Headers**: Always check `X-API-Quota-Left` to warn users before quota runs out
3. **Filter Locally**: Spoonacular may not have perfect vegetarian filtering, so filter results client-side
4. **Handle Edge Cases**: Some restaurants may not have complete data (missing phone, address, etc.)
5. **Respect Rate Limits**: Implement request throttling to stay within 60 requests/minute

## Testing

1. Test with various locations (Jersey City, Pittsburgh, etc.)
2. Test vegetarian filtering
3. Test rate limiting by making rapid requests
4. Test quota exceeded scenario (when possible)
5. Test with invalid coordinates

## Migration from Mock Data

The current mock implementation can be kept as a fallback:

```swift
func searchRestaurants(...) async throws -> [Restaurant] {
    // Try real API first
    if !configService.spoonacularApiKey.isEmpty {
        return try await searchRestaurantsSpoonacular(...)
    } else {
        // Fallback to mock for development/testing
        logger.warning("Using mock restaurant data - add Spoonacular API key for real results", category: .restaurant)
        return try await searchRestaurantsMock(...)
    }
}
```

## Additional Spoonacular Features

Spoonacular also offers:
- **Menu item search**: Can help identify vegetarian dishes at restaurants
- **Product search**: Could help find vegetarian grocery items
- **Recipe search**: Could suggest vegetarian recipes if restaurant search fails

Consider adding these as fallbacks or complementary features.
