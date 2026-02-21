---
phase: 04-loom-chat
plan: 02
subsystem: ui
tags: [swiftui, chat, markdown, swift-markdown-ui, iMessage, bubbles, animations]

# Dependency graph
requires:
  - phase: 04-01
    provides: ChatViewModel with subscription, sendMessage, retryMessage, pendingMessageContent, isLoomAvailable, timedOutMessageIds

provides:
  - ChatBubbleView — iMessage-style bubbles (user accent right, Loom gray left with MarkdownUI rendering)
  - TypingIndicatorView — animated three-dot indicator with staggered pulse and Loom avatar
  - SuggestionChipsView — tappable conversation starters in wrapping FlowLayout, empty state
  - ChatInputBar — text field + send button, disabled state when Loom offline
  - ChatView — full-screen chat compositor with offline banner, message grouping, timeout retry, scroll-to-bottom
affects: [04-03-tab-integration, ui-layer]

# Tech tracking
tech-stack:
  added: [swift-markdown-ui 2.0.0+]
  patterns:
    - FlowLayout custom Layout for wrapping chip grid
    - Message grouping with 5-minute gap threshold and today/yesterday/date formatting
    - ScrollViewReader + defaultScrollAnchor(.bottom) + onChange scrollTo for auto-scroll
    - @ObservedObject (not @StateObject) for shared ChatViewModel passed from parent

key-files:
  created:
    - LoomCal/Views/Chat/ChatBubbleView.swift
    - LoomCal/Views/Chat/TypingIndicatorView.swift
    - LoomCal/Views/Chat/SuggestionChipsView.swift
    - LoomCal/Views/Chat/ChatInputBar.swift
    - LoomCal/Views/Chat/ChatView.swift
  modified:
    - LoomCal.xcodeproj/project.pbxproj

key-decisions:
  - "swift-markdown-ui 2.0.0+ added via pbxproj SPM section — MarkdownUI renders in Loom bubbles only, user messages plain Text"
  - "@ObservedObject for ChatViewModel in ChatView — owned by ContentView/App level, not instantiated in ChatView"
  - "FlowLayout custom Layout protocol for chip wrapping — no UICollectionView, pure SwiftUI"
  - "5-minute gap threshold for message grouping — arbitrary but matches iMessage convention"
  - "defaultScrollAnchor(.bottom) + manual scrollTo on messages.count — handles both initial load and new messages"
  - "ChatViewModel.swift registered in pbxproj — file existed on disk from Plan 01 but was missing from project file"

patterns-established:
  - "iMessage bubble pattern: user accent right with Spacer(minLength: 60), Loom gray left with avatar + name label"
  - "Offline state: orange banner + disabled input + error bubble with retry tap gesture"
  - "Empty state: SuggestionChipsView replaces message list, chips call sendMessage directly"

requirements-completed: [LOOM-01, LOOM-02, LOOM-03, LOOM-04]

# Metrics
duration: 6min
completed: 2026-02-21
---

# Phase 4 Plan 02: Loom Chat UI Views Summary

**Five SwiftUI chat views with iMessage-style bubbles, swift-markdown-ui Markdown rendering, animated typing indicator, and offline error states**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-21T20:09:33Z
- **Completed:** 2026-02-21T20:16:00Z
- **Tasks:** 2
- **Files modified:** 6 (5 created, 1 modified)

## Accomplishments
- ChatBubbleView renders iMessage-style bubbles — user messages right in accent color, Loom messages left in gray with MarkdownUI Markdown rendering
- TypingIndicatorView shows animated three-dot pulsing with staggered 0.2s delays and matching Loom purple avatar
- SuggestionChipsView shows tappable conversation starters in a custom FlowLayout that wraps chips on narrow screens
- ChatInputBar grays out when Loom is offline, send button disabled when text is empty or offline
- ChatView composes all subviews with offline orange banner, 5-minute message grouping, scroll-to-bottom, timeout retry bubble, and suggestion chips empty state
- swift-markdown-ui SPM dependency added; ChatViewModel.swift registered in pbxproj (was on disk but missing from project)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add swift-markdown-ui SPM + ChatBubbleView, TypingIndicatorView, SuggestionChipsView** - `9754087` (feat)
2. **Task 2: ChatInputBar and ChatView — full-screen chat interface** - `39c47bd` (feat)

## Files Created/Modified
- `LoomCal/Views/Chat/ChatBubbleView.swift` — iMessage-style bubble, Markdown in Loom bubbles via MarkdownUI, plain Text for user
- `LoomCal/Views/Chat/TypingIndicatorView.swift` — animated three-dot indicator with Loom avatar, staggered easeInOut animation
- `LoomCal/Views/Chat/SuggestionChipsView.swift` — tappable chips in FlowLayout, Loom avatar + intro, 4 preset suggestions
- `LoomCal/Views/Chat/ChatInputBar.swift` — text field with disabled state, send button color changes, onSubmit for Return key
- `LoomCal/Views/Chat/ChatView.swift` — full compositor: offline banner, grouped messages, typing indicator, timeout retry, empty state
- `LoomCal.xcodeproj/project.pbxproj` — added swift-markdown-ui package, Chat group, ChatViewModel registration, all 5 view files

## Decisions Made
- `@ObservedObject` used in ChatView (not `@StateObject`) — ChatViewModel is owned at ContentView/App level and passed down; creating it inside ChatView would reset state on tab switch
- `FlowLayout` custom Layout protocol used for chip wrapping — avoids UIKit or third-party layout dependencies
- 5-minute gap threshold for message grouping — matches iMessage convention, today/yesterday/date formatting
- `defaultScrollAnchor(.bottom)` combined with manual `scrollTo` on `messages.count` change handles both initial load position and new message arrival
- ChatViewModel.swift was on disk from Plan 01 but missing from pbxproj — registered during this plan as part of pbxproj updates

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered ChatViewModel.swift in pbxproj**
- **Found during:** Task 1 (pbxproj edit for SPM dependency)
- **Issue:** ChatViewModel.swift existed on disk from Plan 01 but was not registered in project.pbxproj — would cause "no such module" or missing symbol errors at build time
- **Fix:** Added PBXBuildFile, PBXFileReference entries and added to PBXSourcesBuildPhase and ViewModels PBXGroup
- **Files modified:** LoomCal.xcodeproj/project.pbxproj
- **Verification:** BUILD SUCCEEDED with no errors
- **Committed in:** `9754087` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Fix was necessary for project to compile. No scope creep.

## Issues Encountered
- Default simulator name "iPhone 16" not found by xcodebuild — used simulator UUID `CE19DC97-23B1-498A-B4FE-03E91FDE962A` to target iOS 18.6 iPhone 16 simulator successfully

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All five chat view files exist and the project compiles clean (BUILD SUCCEEDED)
- ChatView is ready to be embedded in ContentView TabView (Plan 03)
- swift-markdown-ui resolved and linked — Markdown renders in Loom bubbles
- ChatViewModel shared state pattern established: ContentView owns the instance, passes via @ObservedObject

---
*Phase: 04-loom-chat*
*Completed: 2026-02-21*

## Self-Check: PASSED

- FOUND: LoomCal/Views/Chat/ChatBubbleView.swift
- FOUND: LoomCal/Views/Chat/TypingIndicatorView.swift
- FOUND: LoomCal/Views/Chat/SuggestionChipsView.swift
- FOUND: LoomCal/Views/Chat/ChatInputBar.swift
- FOUND: LoomCal/Views/Chat/ChatView.swift
- FOUND: .planning/phases/04-loom-chat/04-02-SUMMARY.md
- FOUND commit: 9754087 (Task 1)
- FOUND commit: 39c47bd (Task 2)
