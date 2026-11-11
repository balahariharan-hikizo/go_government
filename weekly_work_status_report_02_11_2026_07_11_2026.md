WEEKLY WORK STATUS REPORT – BALAHARIHARAN
Project Name: GoGovernment Platform
Modules: Citizen App, Store App, Rider App, Admin Web Portal & Central Node.js Backend
Reporting Period: 02/11/2026 – 07/11/2026

1. EXECUTIVE SUMMARY
During this reporting period, the primary engineering focus was on modularizing the Admin Web Portal architecture, implementing an enterprise Role-Based Access Control (RBAC) authentication engine, constructing an interactive Smart City GIS Command Center with hybrid map tiles and compliant attribution, establishing zero-loss rider telemetry and live duty synchronization, decoupling store state management, and hardening real-time socket dispatch persistence across the central Node.js backend.

Key accomplishments included:
• Refactored the monolithic Admin Dashboard into 5 decoupled, independently maintainable tab view modules (ComplaintsTabView, DispatchTabView, StoresTabView, FeedbackTabView, and CityMapTabView).
• Designed and deployed a complete Admin Authentication system with role-based permissions (Super Admin vs. Officer), secure bcrypt credential hashing, 12-hour signed JWT tokens, and automated Super Admin database seeding.
• Built a multi-layer geospatial command interface powered by high-speed Google Maps raster tiles with zero-downtime automatic OpenStreetMap (OSM) failover, real-time fleet/grievance/store rendering, and cross-tab View on Map camera focus.
• Integrated a brand-compliant multi-colored Powered by Google badge with dynamic OSM copyright fallback, and hardened the Command Layers control panel against horizontal RenderFlex layout overflows.
• Eliminated coordinate zeroing (0, 0) upon rider disconnects or offline toggles by persisting last-known GPS coordinates to MongoDB and ensuring bidirectional duty status synchronization on application initialization.
• Restored real-time rider profile duty status directly from MongoDB into local Hive cache and DeliveryBloc state upon application startup.
• Decoupled store state management by creating dedicated CategoryBloc and OrderBloc architectures, accompanied by live MongoDB store open/closed duty synchronization.
• Refined the socket-driven dispatch algorithm with tiered multi-round radial expansions (2km -> 6km -> Broadcast) integrated with 30-second escalation timers and FCM background wake-up triggers.

2. KEY MODULE IMPLEMENTATION & MAJOR ACCOMPLISHMENTS
MODULE 01: ADMIN WEB PORTAL – ENTERPRISE MODULAR ARCHITECTURE & RBAC AUTHENTICATION

A. Dashboard Architecture Modularization & Tab View Decoupling
Files: admin_dashboard_screen.dart, complaints_tab_view.dart, dispatch_tab_view.dart, stores_tab_view.dart, feedback_tab_view.dart, city_map_tab_view.dart
Completed Work:
• Decoupled the monolithic 2,500+ line admin_dashboard_screen.dart into specialized, independent tab views located in domain-specific directories (complaints/, dispatch/, stores/, feedback/, map/).
• Standardized common table layouts, responsive metric summary cards, search debouncing, and pagination across all desktop tabs.
• Integrated dynamic badge indicators (Live GPS, Last Known, Offline, Location Pending) within the Live Dispatch table.
• Extracted reusable modal dialogs into organized subdirectories (officers/, navbar/, common/).

B. Enterprise RBAC Authentication & Officer Administration
Files: admin_login_screen.dart, officers_directory_dialog.dart, register_officer_dialog.dart, reset_officer_password_dialog.dart, change_password_dialog.dart
Completed Work:
• Built a standalone, branded AdminLoginScreen featuring form validation, animated loading states, password visibility toggles, and secure credential handling.
• Engineered a Role-Based Access Control (RBAC) hierarchy distinguishing between superadmin and desk officer privileges.
• Implemented OfficersDirectoryDialog allowing Super Admins to monitor registered municipal officers, account creation dates, and active statuses.
• Created RegisterOfficerDialog for administrative officer account provisioning.
• Implemented ResetOfficerPasswordDialog enabling administrative password resets, alongside ChangePasswordDialog for self-service credential updates.

C. Backend JWT Security Infrastructure & Session Lifecycle
Files: backend/models/Admin.js, backend/controllers/adminAuthController.js, backend/middleware/adminAuth.js, backend/routes/adminAuthRoutes.js, backend/utils/adminSeed.js, admin_web/lib/services/admin_api_service.dart
Completed Work:
• Defined the Mongoose Admin schema with salt-hashed passwords using bcryptjs (10 rounds) and strict role enumeration (superadmin, officer).
• Implemented JWT issuance with a strict 12-hour session expiration window (expiresIn: '12h').
• Engineered the adminAuth middleware to intercept, decode, and validate HTTP Authorization: Bearer <token> headers, enforcing role guards (requireSuperAdmin).
• Created an automated seed utility (adminSeed.js) that provisions a default Super Admin account upon server boot if no admin exists.
• Updated AdminApiService to centrally manage authentication tokens, user profile metadata in SharedPreferences, and automatic authorization header injection on all outbound administrative requests.

Technical Outcome:
Transformed the Admin Web desk into an enterprise-grade platform with modular frontend state handling, secured end-to-end with cryptographic JWT authentication and role-enforced administrative endpoints.

MODULE 02: SMART CITY GIS COMMAND CENTER & CROSS-PLATFORM GEO-INTEGRATION

A. Dual-Engine Hybrid Map Architecture
File: admin_web/lib/widgets/map/city_map_tab_view.dart
Completed Work:
• Implemented a hybrid tile-rendering system utilizing Google Maps raster tiles across subdomains 0 through 3 as the primary map provider.
• Engineered an automated failover mechanism via errorTileCallback: if tile loading errors reach threshold (>= 4), the map seamlessly switches to OpenStreetMap (tile.openstreetmap.org) without screen freeze or user disruption.
• Integrated flutter_map_cancellable_tile_provider (CancellableNetworkTileProvider) to cancel superseded HTTP tile requests during rapid panning and zooming, eliminating network bottlenecks on web browsers.

B. Unified Multi-Layer Real-Time GIS Visualization
Completed Work:
• Civic Grievances Layer: Plotted live citizen grievances using priority-coded markers: Red (Pending), Amber (In-Progress), and Green (Resolved), with immediate popup inspection modals.
• Fair Price Ration Stores Layer: Rendered geo-tagged government ration shops with store IDs, dealer names, and contact details.
• Rider Logistics Fleet Layer: Visualized active delivery riders on the city map with dynamic status indicators: Blue markers with pulse for Online active riders and Slate markers for Offline riders.

C. Cross-Tab "View on Map" Camera Flight Navigation
Completed Work:
• Engineered seamless deep-linking between administrative tables and the GIS map.
• Clicking "View on Map" within the Grievance Desk or Store Directory automatically navigates to the City Map tab and initiates an animated camera flight (_focusOnEntity) to the exact latitude and longitude of the target entity at zoom level 16.0.

D. Compliant Brand Attribution & Responsive Hardening
Completed Work:
• Added a compliant, semi-transparent "Powered by Google" attribution badge featuring the official multi-colored typography (G-blue, o-red, o-yellow, g-blue, l-green, e-red).
• Implemented automatic attribution text switching to "Map data © OpenStreetMap contributors" when OSM failover is active.
• Resolved a horizontal RenderFlex layout overflow (21px) within the Command Layers control header by converting the title into a flexible Expanded layout and optimizing the provider badge chip (Google / OSM).

Technical Outcome:
Delivered a high-performance, legally compliant Smart City GIS Command Map capable of real-time multi-layer entity inspection with sub-second failover and fluid cross-tab coordinate navigation.

MODULE 03: RIDER FLEET TELEMETRY & LIVE DUTY STATE SYNCHRONIZATION

A. Live Duty Status Synchronization with Central Database
Files: rider_app/lib/screen/home/rider_dashboard_screen.dart, rider_app/lib/bloc/delivery/delivery_bloc.dart, rider_app/lib/bloc/delivery/delivery_event.dart
Completed Work:
• Engineered real-time profile duty verification (_syncRealRiderProfile) during rider dashboard initialization.
• Synchronized the actual MongoDB Rider isOnline status directly into local Hive storage and DeliveryBloc state using ToggleDutyEvent(syncOnly: true).
• Prevented redundant network mutations during initial application launch while ensuring complete state alignment between client and server.

B. Zero-Loss Coordinate Retention in Database & Live Registry
Files: backend/sockets/socketHandler.js, backend/controllers/orderController.js, backend/controllers/riderController.js
Completed Work:
• Eliminated coordinate zeroing (0, 0) in the backend in-memory riderRegistry when riders go offline or disconnect.
• Preserved last-known valid coordinates across all offline transitions, ensuring that nearest-rider dispatch and administrative dispatch tables retain geographic history.
• Persisted live coordinates directly into MongoDB Rider.currentLocation on every incoming location ping.
• Safeguarded order controller logic to prevent overwriting active rider coordinates with uninitialized values.

Technical Outcome:
Guaranteed 100% telemetry integrity for the rider fleet, eliminating missing coordinate records in MongoDB and ensuring reliable duty status synchronization across application restarts.

MODULE 04: STORE APP & CENTRAL BACKEND SYSTEM REFACTORING

A. Store App BLoC Architecture Decoupling
Files: store_app/lib/bloc/category/, store_app/lib/bloc/order/, store_app/lib/screen/store/store_dashboard_screen.dart
Completed Work:
• Refactored the Store App state management by separating concerns into dedicated CategoryBloc and OrderBloc architectures.
• Implemented live MongoDB store status synchronization on dashboard initialization, ensuring that store open/closed states accurately reflect backend database reality.

B. Central Backend Socket & Targeted Radial Dispatch Engine
File: backend/sockets/socketHandler.js
Completed Work:
• Maintained targeted 3-tier dispatch logic:
  o Round 1: Nearest riders within a 2km radius (top 3 riders).
  o Round 2: Expanded search to a 6km radius (top 3 riders) after a 30-second escalation timeout.
  o Round 3: Broadcast to all active, idle online riders.
• Integrated FCM background wake-up push notifications targeted to assigned riders to awaken sleeping application instances upon order dispatch.

Technical Outcome:
Established a resilient dispatch pipeline backed by decoupled state management on store terminals and low-latency WebSocket communication.

3. END-TO-END PLATFORM FLOW TESTING & VERIFICATION
Completed comprehensive end-to-end verification of the following 14 key platform workflows across the ecosystem:

1. Admin Secure Login & Session Handling
• Tested admin credential verification with bcrypt password matching.
• Verified JWT token generation, 12-hour session expiration, and automatic bearer authorization header attachment.

2. Officer Provisioning & Administration
• Verified Super Admin officer creation via RegisterOfficerDialog.
• Tested password change workflows and Super Admin administrative password resets.

3. Smart City GIS Map Hybrid Tile Rendering
• Verified default Google Maps raster tile rendering.
• Tested simulated tile error triggers and confirmed automated failover to OpenStreetMap tiles.

4. Cross-Tab "View on Map" Interactive Navigation
• Tested clicking "View on Map" from the Grievance table; verified automatic tab transition and animated camera flight to exact grievance coordinates.
• Verified store location camera focusing from the Store Management tab.

5. GIS Multi-Layer Control & Marker Filtering
• Verified real-time toggle visibility for Pending, In-Progress, and Resolved grievances.
• Tested live fleet marker rendering (Blue for Online riders, Slate for Offline riders).

6. Rider Offline Coordinate Retention
• Verified that toggling rider status to offline or disconnecting network retains last-known coordinates in MongoDB instead of wiping to (0, 0).

7. Rider Dashboard Live MongoDB State Sync
• Tested app restart with active online status in MongoDB; verified automatic duty state restoration in Hive storage and DeliveryBloc.

8. Store Dashboard Live Status Synchronization
• Tested store open/closed toggling and verified synchronization with MongoDB on dashboard initialization.

9. Store Order Queue BLoC Flow
• Tested incoming order reception, commodity packing inspection, and ready-for-pickup handoff workflows via OrderBloc.

10. Store Category Management BLoC Flow
• Tested category creation, sub-category nesting, and live product counter rollups through CategoryBloc.

11. Targeted Multi-Round Radial Dispatch Escalation
• Tested order assignment within 2km (Round 1); verified automated 30-second escalation to 6km (Round 2) when unaccepted.

12. Rider Order Dispatch Wake-Up & Full-Screen Dialog
• Tested dispatch arrival while the Rider App was minimized; verified screen wake-up, custom alarm audio playback, and order prompt display.

13. Citizen Civic Grievance Submission & Real-Time Tracking
• Tested complaint logging with photo attachments and reverse-geocoded GPS coordinates.
• Verified real-time status reflection in the Admin Complaints tab.

14. Admin Dispatch Tab Fleet Monitoring
• Tested live rider telemetry table sorting; verified online riders with active GPS display green live badges while offline riders show last-known timestamps.

4. CODE QUALITY, PERFORMANCE & PLATFORM HEALTH

A. Backend Security & Performance
• Role-Based API Security: Enforced strict JWT authentication and Super Admin authorization middleware across administrative routes.
• Database Optimization: Minimized write amplification by utilizing targeted $set operators on nested MongoDB documents (currentLocation.lat, currentLocation.lng) during rapid GPS ping updates.
• In-Memory Registry: Maintained a centralized in-memory rider registry (riderRegistry) for fast radial distance calculations without querying MongoDB on every dispatch tick.

B. Frontend & Mobile Responsiveness
• Zero Tile Bottlenecks: Integrated flutter_map_cancellable_tile_provider to prevent HTTP request queue starvation during rapid user pan and zoom operations.
• Layout Overflow Prevention: Replaced rigid flex spacers with flexible Expanded widgets and boundary constraints across Admin Web header components.
• UI & Memory Optimization: Eliminated redundant widget re-renders and memory overhead across dispatch feeds and mobile viewports.

Overall Objective
Continue advancing the GoGovernment Platform by enhancing the GIS spatial dispatch engine, strengthening administrative oversight tools, maintaining robust mobile background synchronization, and delivering an intuitive, unified digital public service experience across Citizen, Store, Rider, and Administrative interfaces.

Report Submitted By:
Balahariharan
