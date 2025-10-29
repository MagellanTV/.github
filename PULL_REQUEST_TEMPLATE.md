
## Ticket

VRT-1234

## Description

Implementation of "My List" screen that allows users to view, organize, and manage their favorite content. The screen includes grid layout, sorting options, and remove functionality.

## Changes Made

- Created MyListScreen component with responsive grid layout
- Added navigation from main menu to My List
- Implemented API integration to fetch user's saved content
- Added functionality to remove items from list
- Created unit tests for new components
- Updated navigation flow documentation
    

## Platform Compatibility

-   [x] iOS - Tested on iPhone 14 simulator
-   [x] Android - Tested on Pixel 7 emulator
-   [x] React Web - Tested on Chrome, Firefox, Safari
-   [x] Roku - Tested on Roku Ultra simulator
-   [x] Samsung TV - Tested on Tizen simulator
-   [x] LG TV - Tested on webOS simulator

## Testing Steps

1.  Log in to the application with valid credentials
2.  Navigate to main menu
3.  Select "My List" option    
4.  Verify that user's saved content displays in grid layout
5.  Test sorting functionality (by date, alphabetical, genre)
6.  Test removing items from the list
7.  Verify empty state when no content is saved
    
8.  Test navigation back to main menu
    

## Evidence

[Attach screenshots or screen recordings showing the feature working on different platforms]

## Additional Information

-   Feature is backward compatible with existing user data
-   Requires internet connection for initial load and sync
-   Offline viewing of cached content still available
-   Performance tested with lists up to 500 items

## Impacted flows / Risks / Dependencies (optional)

This PR also impacts UI the following UI components…….

## Out of Scope Notes (optional)

I found an issue related to Authentication flow, I have created a separate ticket to add a try catch to handle the Exception.
