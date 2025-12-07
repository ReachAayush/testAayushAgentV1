# Production Tasks: Restaurant Reservation Workflow

This document outlines the tasks needed to move the restaurant reservation agentic workflow from mock data to production-ready implementation with real API integrations.

## Overview

The current implementation uses mock data for restaurant discovery and reservations. To make this production-ready, we need to:

1. Integrate real APIs (Yelp Fusion, OpenTable, Rezzy)
2. Implement robust error handling
3. Add configuration management for API keys
4. Improve user experience with better error messages

---

## 1. Integrate Real APIs

### 1.1 Replace Mock Data in RestaurantDiscoveryService

**Current State:** `RestaurantDiscoveryService.swift` returns hardcoded mock restaurants.

**Tasks:**

#### A. Set up Spoonacular Food API (RECOMMENDED - Free Tier Available)

1. **Get Spoonacular API Credentials:**
   - Sign up at https://spoonacular.com/food-api
   - Free tier provides 150 requests/day
   - Get your API key from the dashboard
   - Document the API key storage location

2. **Update RestaurantDiscoveryService:**
   - Add Spoonacular API client initialization
   - Replace `searchRestaurants()` method with real Spoonacular API calls
   - Use endpoint: `https://api.spoonacular.com/food/restaurants/search`
   - Map Spoonacular API response to `Restaurant` model

3. **Required Parameters:**
   ```swift
   - lat: Double (latitude)
   - lng: Double (longitude)
   - distance: Double (miles, optional)
   - query: String (optional, restaurant name or cuisine)
   - cuisine: String (optional, e.g., "italian", "vegetarian")
   - min-rating: Double (optional, 0-5)
   - is-open: Bool (optional)
   - sort: String (optional: "distance", "rating", "cheapest", "fastest", "relevance")
   - page: Int (optional, for pagination)
   - apiKey: String (required in query params or header)
   ```

4. **Response Mapping:**
   - Map Spoonacular `restaurant` object to `Restaurant` struct
   - Extract: `name`, `weighted_rating_value` (rating), `dollar_signs` (price level)
   - Extract address from `address` object (street_addr, city, state, zipcode)
   - Extract coordinates: `address.lat`, `address.lon`
   - Extract phone: `phone_number`
   - Determine vegetarian friendliness from `cuisines` array or search query
   - For reservation provider: Check if restaurant supports delivery/pickup, or use OpenTable/Rezzy lookup

5. **Spoonacular Response Structure:**
   ```json
   {
     "restaurants": [
       {
         "_id": "...",
         "name": "Restaurant Name",
         "phone_number": 14159741115,
         "address": {
           "street_addr": "123 Main St",
           "city": "Jersey City",
           "state": "NJ",
           "zipcode": "07302",
           "lat": 40.7178,
           "lon": -74.0431
         },
         "dollar_signs": 2,
         "weighted_rating_value": 4.5,
         "cuisines": ["Italian", "Vegetarian", "Pizza"],
         "is_open": true,
         "pickup_enabled": true,
         "delivery_enabled": true
       }
     ]
   }
   ```

6. **Error Handling:**
   - Handle rate limiting (429 status) - Free tier: 60 requests/minute
   - Handle quota exceeded (402 status) - Check `X-API-Quota-Left` header
   - Handle invalid location
   - Handle network errors
   - Log API errors with context

**Files to Modify:**
- `AayushTestAppV1/Services/RestaurantDiscoveryService.swift`
- `AayushTestAppV1/Services/ConfigurationService.swift` (add Spoonacular API key)

**Reference:**
- Spoonacular Restaurant Search API: https://spoonacular.com/food-api/docs#Search-Restaurants
- Authentication: API key as query parameter `?apiKey=YOUR_KEY` or header `x-api-key`
- Rate Limits: Free tier = 60 requests/minute, 150 points/day
- API Costs: 3 points per restaurant search request

**Alternative: Yelp Fusion API** (if Spoonacular doesn't meet needs)
- Sign up at https://www.yelp.com/developers
- Endpoint: `https://api.yelp.com/v3/businesses/search`
- Authentication: Bearer token in Authorization header
- Note: Yelp requires business verification for production use

---

### 1.2 Integrate OpenTable API in ReservationService

**Current State:** `ReservationService.swift` returns mock reservation confirmations.

**Tasks:**

#### A. Set up OpenTable API

1. **Get OpenTable API Access:**
   - Contact OpenTable Partner Integration team
   - Apply for API access at https://www.opentable.com/partners
   - Get API credentials (API key and secret)
   - Understand rate limits and usage terms

2. **Update ReservationService:**
   - Add OpenTable API client
   - Implement `makeReservation()` with real API calls
   - Find restaurant by OpenTable ID from Yelp data or restaurant lookup
   - Submit reservation request

3. **Required Data:**
   ```swift
   - restaurantId: String (OpenTable restaurant ID)
   - date: Date
   - partySize: Int
   - dinerName: String
   - dinerEmail: String
   - dinerPhone: String
   ```

4. **Response Handling:**
   - Extract confirmation number
   - Store reservation details
   - Handle booking conflicts
   - Handle unavailable time slots

5. **Error Handling:**
   - Handle "restaurant not found on OpenTable"
   - Handle "time slot unavailable"
   - Handle "party size too large"
   - Handle rate limiting
   - Retry logic for transient failures

**Files to Modify:**
- `AayushTestAppV1/Services/ReservationService.swift`
- `AayushTestAppV1/Services/ConfigurationService.swift` (add OpenTable credentials)

**Alternative Approach:**
- Use OpenTable deep links if API access is restricted
- Format: `https://www.opentable.com/r/[restaurant-name]?DateTime=[ISO8601]&PartySize=[N]`

---

### 1.3 Add Rezzy API Integration (Optional)

**Current State:** Rezzy mentioned as reservation provider but not implemented.

**Tasks:**

1. **Research Rezzy API:**
   - Determine if Rezzy has a public API
   - Check if they have partner integration program
   - Understand authentication requirements

2. **If API Available:**
   - Implement Rezzy client similar to OpenTable
   - Add provider detection logic
   - Update reservation flow to handle both providers

3. **If No API:**
   - Use deep link approach (if available)
   - Or remove Rezzy from supported providers list

**Files to Modify:**
- `AayushTestAppV1/Services/ReservationService.swift`
- Update `Restaurant` model if needed

---

## 2. Error Handling

### 2.1 Handle API Rate Limits

**Current State:** No rate limit handling.

**Tasks:**

1. **Rate Limit Detection:**
   - Monitor HTTP 429 (Too Many Requests) responses
   - Extract `Retry-After` header if present
   - Log rate limit events

2. **Rate Limit Handling:**
   - Implement exponential backoff
   - Queue requests when rate limited
   - Show user-friendly message: "Too many requests. Please try again in X seconds"

3. **Rate Limit Prevention:**
   - Cache restaurant search results (5-10 minutes)
   - Debounce rapid API calls
   - Consider user-level rate limiting

**Files to Modify:**
- `AayushTestAppV1/Services/RestaurantDiscoveryService.swift`
- `AayushTestAppV1/Services/ReservationService.swift`
- Add retry utility/extension

**Implementation Example:**
```swift
func handleRateLimit(error: Error, retryAfter: TimeInterval?) async throws {
    if let retryAfter = retryAfter {
        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
    } else {
        // Exponential backoff
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }
}

// For Spoonacular: Check quota headers
// X-API-Quota-Left: remaining points
// X-API-Quota-Used: points used today
// X-API-Quota-Request: points for this request
```

---

### 2.2 Add Retry Logic for Failed Reservations

**Current State:** Single attempt, no retries.

**Tasks:**

1. **Transient Error Detection:**
   - Network timeouts
   - HTTP 5xx errors
   - Rate limiting

2. **Retry Strategy:**
   - Max 3 retry attempts
   - Exponential backoff: 1s, 2s, 4s
   - Only retry transient errors
   - Don't retry user errors (400, 401, 404)

3. **User Feedback:**
   - Show "Retrying..." status
   - After max retries, show clear error
   - Allow manual retry button

**Files to Modify:**
- `AayushTestAppV1/Services/ReservationService.swift`
- `AayushTestAppV1/Features/Actions/RestaurantReservationAction.swift`

---

### 2.3 Improve User Feedback for Edge Cases

**Current State:** Generic error messages.

**Tasks:**

1. **Specific Error Messages:**
   - "No restaurants found near your location. Try expanding your search radius."
   - "This restaurant doesn't accept reservations for parties of [N]. Maximum is [M]."
   - "The selected time slot is no longer available. Please choose another time."
   - "Restaurant is closed on [day]. Please select a different date."

2. **Validation Before API Calls:**
   - Check party size limits (1-20)
   - Validate date is in future
   - Validate date is within booking window
   - Check email format

3. **Empty States:**
   - "No vegetarian restaurants found. Try removing the vegetarian filter."
   - "No restaurants available for [date]. Try another date."

4. **Loading States:**
   - Show progress: "Searching restaurants..."
   - Show progress: "Making reservation..."
   - Show progress: "Confirming details..."

**Files to Modify:**
- `AayushTestAppV1/Features/Views/RestaurantReservationView.swift`
- `AayushTestAppV1/Features/Actions/RestaurantReservationAction.swift`
- `AayushTestAppV1/Core/AppError.swift` (add specific error types)

---

## 3. Configuration

### 3.1 Add API Keys to Configuration Service

**Current State:** API keys would be hardcoded or missing.

**Tasks:**

1. **Update ConfigurationService:**
   - Add `spoonacularApiKey: String` property (RECOMMENDED)
   - Add `yelpApiKey: String` property (optional alternative)
   - Add `opentableApiKey: String` property
   - Add `opentableApiSecret: String?` property (if required)
   - Add `rezzyApiKey: String?` property (if implemented)

2. **Storage:**
   - Store in Keychain via `CredentialManager`
   - Add to `AppConfig.plist` for default values (for development)
   - Never commit real keys to git

3. **Loading Priority:**
   - Keychain (highest priority)
   - UserDefaults (for overrides)
   - AppConfig.plist (defaults)

4. **Validation:**
   - Validate keys are present before making API calls
   - Show helpful error if keys missing

**Files to Modify:**
- `AayushTestAppV1/Services/ConfigurationService.swift`
- `AayushTestAppV1/Services/CredentialManager.swift`
- `AayushTestAppV1/AppConfig.plist`
- Add configuration UI in settings (optional)

**Implementation:**
```swift
enum ConfigKey: String {
    case spoonacularApiKey = "SPOONACULAR_API_KEY"
    case yelpApiKey = "YELP_API_KEY"  // Optional alternative
    case opentableApiKey = "OPENTABLE_API_KEY"
    // ...
}

extension ConfigurationService {
    var spoonacularApiKey: String {
        get { get(.spoonacularApiKey) ?? "" }
    }
    
    var yelpApiKey: String {
        get { get(.yelpApiKey) ?? "" }
    }
}
```

---

### 3.2 Make Reservation Providers Configurable

**Current State:** Reservation provider determined by restaurant data.

**Tasks:**

1. **Provider Selection Logic:**
   - Check restaurant supports OpenTable
   - Check restaurant supports Rezzy
   - Allow user preference (if applicable)
   - Fallback order: OpenTable → Rezzy → Direct call

2. **Provider Configuration:**
   - Enable/disable providers via config
   - Set provider priority
   - Allow testing specific providers

3. **UI Updates:**
   - Show which provider will be used
   - Allow user to choose provider if multiple available
   - Show provider name in confirmation

**Files to Modify:**
- `AayushTestAppV1/Services/ReservationService.swift`
- `AayushTestAppV1/Features/Actions/RestaurantReservationAction.swift`
- `AayushTestAppV1/Services/ConfigurationService.swift`

---

## 4. Additional Considerations

### 4.1 Testing

- [ ] Unit tests for API clients
- [ ] Integration tests with test API keys
- [ ] Mock API responses for UI testing
- [ ] Test rate limit handling
- [ ] Test error scenarios

### 4.2 Monitoring & Logging

- [ ] Log API call metrics (duration, success/failure)
- [ ] Track reservation success rate
- [ ] Monitor API error rates
- [ ] Alert on repeated failures

### 4.3 Performance

- [ ] Cache restaurant search results
- [ ] Optimize API call frequency
- [ ] Batch requests where possible

### 4.4 User Experience

- [ ] Add "favorite restaurants" feature
- [ ] Save recent reservations
- [ ] Allow rescheduling/canceling
- [ ] Email/SMS confirmation

---

## Implementation Priority

**High Priority (MVP):**
1. Spoonacular Restaurant Search API integration (free tier available)
2. OpenTable API integration (or deep link fallback)
3. API keys in ConfigurationService
4. Basic error handling

**Medium Priority:**
1. Rate limit handling
2. Retry logic
3. Better error messages

**Low Priority:**
1. Rezzy API (if needed)
2. Advanced caching
3. Provider selection UI

---

## Notes

- Keep mock data implementation as fallback for testing
- Add feature flags to switch between mock and real APIs
- Document all API endpoints and authentication in code
- Consider using a networking library (Alamofire) for easier API management
- Review API terms of service for each provider
