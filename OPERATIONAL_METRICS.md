# Operational Metrics Strategy

**Last Updated**: December 2024  
**Status**: TODO Comments Added - Implementation Pending

This document outlines the operational metrics strategy for the Aayush Agent iOS application. All metrics are currently implemented as debug logging statements using `LoggingService`. Future implementation will emit these to CloudWatch or another metrics aggregation service.

---

## 📊 Metrics Categories

### 1. **LLM/API Metrics** (`llm.*`)

**Purpose**: Monitor LLM API performance, reliability, and usage patterns.

**Key Metrics**:
- `llm.request.initiated` (counter) - Total LLM API requests
- `llm.request.duration` (histogram) - Request latency in milliseconds
- `llm.request.success` (counter) - Successful requests
- `llm.request.failure` (counter) - Failed requests
- `llm.request.status_code` (counter) - HTTP status code distribution
- `llm.request.method` (gauge) - Authentication method (SigV4 vs Bearer)
- `llm.request.size.request` (histogram) - Request payload size in bytes
- `llm.request.size.response` (histogram) - Response payload size in bytes
- `llm.request.error.type` (counter) - Error types (http_4xx, http_5xx, invalid_response, etc.)
- `llm.response.length` (histogram) - Length of generated messages
- `llm.response.tokens` (histogram) - Token usage (if available in response)

**Location**: `Services/LLMClient.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 2. **Action Execution Metrics** (`action.*`)

**Purpose**: Track user action usage, success rates, and performance.

**Key Metrics**:
- `action.execution.initiated` (counter) - Total action executions
- `action.execution.type` (counter) - Action type (hello, schedule, transit)
- `action.execution.duration` (histogram) - Action execution latency in milliseconds
- `action.execution.success` (counter) - Successful executions
- `action.execution.failure` (counter) - Failed executions
- `action.execution.error.type` (counter) - Error types by action
- `action.execution.type.success` (counter) - Success by action type
- `action.execution.type.failure` (counter) - Failure by action type

**Action-Specific Metrics**:
- `action.hello.initiated` (counter) - Hello action executions
- `action.hello.recipient` (counter) - Recipient names (anonymized)
- `action.hello.has_timezone` (counter) - Actions with timezone specified
- `action.hello.has_style_hint` (counter) - Actions with style hints
- `action.schedule.initiated` (counter) - Schedule action executions
- `action.schedule.calendar_filter` (counter) - Actions with calendar filtering
- `action.schedule.calendar_count` (histogram) - Number of calendars queried

**Location**: 
- `Controllers/AgentController.swift`
- `Features/Actions/HelloMessageAction.swift`
- `Features/Actions/TodayScheduleSummaryAction.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 3. **Calendar Service Metrics** (`calendar.*`)

**Purpose**: Monitor calendar access patterns and performance.

**Key Metrics**:
- `calendar.permission.request` (counter) - Permission request attempts
- `calendar.permission.granted` (counter) - Permission grants
- `calendar.permission.denied` (counter) - Permission denials
- `calendar.permission.error` (counter) - Permission request errors
- `calendar.permission.status` (gauge) - Current permission status
- `calendar.fetch.initiated` (counter) - Calendar fetch attempts
- `calendar.fetch.duration` (histogram) - Fetch latency in milliseconds
- `calendar.fetch.events.count` (histogram) - Number of events found
- `calendar.fetch.calendar_count` (histogram) - Number of calendars queried
- `calendar.fetch.success` (counter) - Successful fetches

**Location**: `Services/CalendarClient.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 4. **Location Service Metrics** (`location.*`)

**Purpose**: Track location access and fetch operations.

**Key Metrics**:
- `location.permission.request` (counter) - Permission request attempts
- `location.permission.granted` (counter) - Permission grants
- `location.permission.denied` (counter) - Permission denials
- `location.permission.status` (gauge) - Current permission status
- `location.permission.status_change` (counter) - Permission status changes
- `location.fetch.initiated` (counter) - Location fetch attempts
- `location.fetch.success` (counter) - Successful location fetches
- `location.fetch.failure` (counter) - Failed location fetches
- `location.fetch.timeout` (counter) - Location fetch timeouts
- `location.fetch.duration` (histogram) - Fetch latency in milliseconds
- `location.fetch.accuracy` (histogram) - Location accuracy in meters
- `location.fetch.error.type` (counter) - Error types

**Location**: `Services/LocationClient.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 5. **Contacts/Messages Service Metrics** (`contacts.*`)

**Purpose**: Monitor contacts access and lookup operations.

**Key Metrics**:
- `contacts.permission.request` (counter) - Permission request attempts
- `contacts.permission.granted` (counter) - Permission grants
- `contacts.permission.denied` (counter) - Permission denials
- `contacts.permission.error` (counter) - Permission request errors
- `contacts.lookup.initiated` (counter) - Contact lookup attempts
- `contacts.lookup.duration` (histogram) - Lookup latency in milliseconds
- `contacts.lookup.contacts_scanned` (histogram) - Number of contacts scanned
- `contacts.lookup.success` (counter) - Successful lookups
- `contacts.lookup.not_found` (counter) - Lookups that didn't find a match

**Location**: `Services/MessagesClient.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 6. **Configuration Metrics** (`config.*`)

**Purpose**: Track configuration loading, validation, and changes.

**Key Metrics**:
- `config.access` (counter) - Configuration value accesses
- `config.source` (counter) - Source used (keychain, userdefaults, infoplist, appconfig, default)
- `config.validation.initiated` (counter) - Validation attempts
- `config.validation.success` (counter) - Validation successes
- `config.validation.failure` (counter) - Validation failures
- `config.validation.missing_keys` (histogram) - Number of missing keys
- `config.validation.status` (gauge) - Validation status (0=valid, 1=invalid)
- `config.llm.rebuild.initiated` (counter) - LLM client rebuilds
- `config.llm.rebuild.completed` (counter) - Successful rebuilds
- `config.llm.rebuild.duration` (histogram) - Rebuild latency in milliseconds

**Location**: 
- `Services/ConfigurationService.swift`
- `App/ContentView.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 7. **Credential Management Metrics** (`credential.*`)

**Purpose**: Monitor credential storage and retrieval operations.

**Key Metrics**:
- `credential.store.initiated` (counter) - Credential storage attempts
- `credential.store.success` (counter) - Successful storage operations
- `credential.store.failure` (counter) - Storage failures
- `credential.store.key` (counter) - Storage by key type
- `credential.store.error.status` (counter) - Keychain error status codes
- `credential.retrieve.initiated` (counter) - Credential retrieval attempts
- `credential.retrieve.success` (counter) - Successful retrievals
- `credential.retrieve.failure` (counter) - Retrieval failures
- `credential.retrieve.not_found` (counter) - Credentials not found
- `credential.retrieve.key` (counter) - Retrieval by key type
- `credential.retrieve.error.status` (counter) - Keychain error status codes
- `credential.retrieve.error.invalid_data` (counter) - Invalid data errors

**Location**: `Services/CredentialManager.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 8. **UI Interaction Metrics** (`ui.*`)

**Purpose**: Track user interface interactions and navigation patterns.

**Key Metrics**:
- `ui.action.selected` (counter) - Action card taps
- `ui.action.type` (counter) - Action type selected (hello, schedule, transit)
- `ui.settings.calendar_opened` (counter) - Calendar settings opens
- `ui.settings.favorites_opened` (counter) - Favorites management opens
- `ui.settings.llm_opened` (counter) - LLM settings opens

**Location**: `UI/HomeView.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 9. **Transit/Directions Metrics** (`transit.*`)

**Purpose**: Monitor transit directions feature usage.

**Key Metrics**:
- `transit.directions.initiated` (counter) - Directions request attempts
- `transit.directions.duration` (histogram) - Directions flow latency
- `transit.directions.success` (counter) - Successful directions
- `transit.directions.failure` (counter) - Failed directions
- `transit.directions.destination` (counter) - Destination name (anonymized)
- `transit.directions.maps_opened` (counter) - Google Maps opened
- `transit.directions.maps_app_available` (counter) - Native app vs web
- `transit.directions.error.type` (counter) - Error types (location, maps, etc.)
- `transit.stops.added` (counter) - Stops added
- `transit.stops.updated` (counter) - Stops updated
- `transit.stops.deleted` (counter) - Stops deleted
- `transit.stops.total` (gauge) - Total number of stops

**Location**: 
- `Features/Views/PATHTrainView.swift`
- `Stores/TransitStopsStore.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

### 10. **Application Lifecycle Metrics** (`app.*`)

**Purpose**: Track app initialization and lifecycle events.

**Key Metrics**:
- `app.init.started` (counter) - App initialization attempts
- `app.init.completed` (counter) - Successful initializations
- `app.init.duration` (histogram) - Initialization latency in milliseconds
- `app.init.config_load.duration` (histogram) - Config loading latency
- `app.init.config_status` (gauge) - Config validation status (0=valid, 1=invalid)

**Location**: `App/ContentView.swift`

**Current Implementation**: Debug logging via `LoggingService.debug()`

---

## 🔍 Metric Types

### Counters
Incrementing metrics that track occurrences of events.
- Examples: `llm.request.initiated`, `action.execution.success`, `calendar.permission.granted`

### Gauges
Metrics that represent a value at a specific point in time.
- Examples: `calendar.permission.status`, `transit.stops.total`, `app.init.config_status`

### Histograms
Metrics that track the distribution of values (typically latencies or sizes).
- Examples: `llm.request.duration`, `calendar.fetch.events.count`, `location.fetch.accuracy`

---

## 📍 Implementation Status

### ✅ Completed
- TODO comments added to all key operational points
- Debug logging statements implemented using `LoggingService`
- Metrics categories defined and documented

### ⏳ Pending
- CloudWatch integration (or alternative metrics service)
- Metric aggregation and export
- Dashboard creation
- Alert configuration
- Performance baseline establishment

---

## 🚀 Future Implementation

### Phase 1: CloudWatch Integration
1. Add AWS SDK for Swift dependency
2. Create `MetricsService` to wrap CloudWatch PutMetricData API
3. Replace debug logging with metric emission
4. Add metric batching for efficiency

### Phase 2: Dashboard & Alerts
1. Create CloudWatch dashboards for key metrics
2. Set up alarms for error rates, latency spikes
3. Configure SNS notifications for critical alerts

### Phase 3: Advanced Analytics
1. Add custom dimensions (user ID, app version, device type)
2. Implement metric sampling for high-volume metrics
3. Add cost optimization (metric filtering, aggregation)

---

## 📝 Notes

- All metrics are currently logged as debug statements for development visibility
- Metric names follow a hierarchical naming convention: `category.operation.metric`
- Sensitive data (names, phone numbers) should be anonymized or hashed before emission
- Consider rate limiting for high-frequency metrics to avoid excessive costs
- Review and adjust metric retention policies based on CloudWatch pricing

---

## 🔗 Related Documentation

- [TECH_DEBT.md](./TECH_DEBT.md) - Technical debt tracking
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [LoggingService.swift](./AayushTestAppV1/Services/LoggingService.swift) - Logging implementation

---

**Maintained By**: Engineering Team  
**Review Frequency**: Quarterly  
**Last Review**: December 2024



