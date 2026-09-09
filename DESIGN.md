# Eristic Implementation: Design Overview

## Problem Statement:
The challenge is to create a user-friendly and engaging tool for learning and identifying the 12 most common informal logical fallacies. Eristic aims to make understanding these fallacies fun and accessible.

## Design Technologies and Patterns:

1. **Swift Programming Language:**
   - **Safety:** Swift's safety features reduce bugs and errors, ensuring a robust codebase.
   - **Performance:** Swift's high-performance capabilities are ideal for resource-intensive applications.

2. **SwiftUI Framework:**
   - **Declarative Syntax:** SwiftUI's syntax is declarative, leading to concise and expressive code.
   - **Cross-Platform Development:** SwiftUI supports multi-platform development for iOS, macOS, watchOS, and tvOS.
   - **Live Preview:** SwiftUI provides a live preview feature for real-time code changes.

3. **MVVM Architectural Pattern:**
   - **Separation of Concerns:** MVVM cleanly separates Model, View, and ViewModel for modular and maintainable code.
   - **Testability:** MVVM enhances testability by isolating business logic in the ViewModel.
   - **Reusability:** MVVM promotes code reusability, reducing redundant development efforts.
   [1] More details about MVVM below.

## Gamification Integration:
To enhance engagement and retention, Eristic incorporates gamification through the Critical Quiz:
   - **Engagement:** Motivational elements boost learner engagement.
   - **Retention:** Interactive experiences improve information retention.
   - **Challenges:** Intrinsic motivation is fostered through challenges and competition.
   - **Immediate Feedback:** Users receive instant feedback on correct or incorrect answers.
   - **Progress Tracking:** Visual representation of progress encourages users to surpass their scores.
   - **Fun and Enjoyment:** The inherent fun factor makes learning enjoyable and approachable.

## Flash Cards Usage:
For efficient learning and memory reinforcement, Eristic utilizes flashcards:
   - **Active Recall:** Users retrieve information, enhancing memory.
   - **Spaced Repetition:** Learning intervals are optimized for memory reinforcement.
   - **Quick and Digestible:** Information is presented in small, manageable chunks.
   - **Efficient Learning:** Focused review is enabled for busy schedules and on-the-go learning.

## User Interface Design:
   - Large, clear buttons ensure easy navigation and readability.
   - Simple colors in light mode enhance the user interface.
   - Cover Flow design pattern is employed for fallacies details, a navigation pattern Apple created for iTunes on the first iPhone.

# [1] MVVM (Model–View–ViewModel) in SwiftUI

## Overview

MVVM is an architectural design pattern that separates the application into three interconnected components: Model, View, and ViewModel. This pattern enhances the maintainability, scalability, and testability of an application.

### Model:
- Represents the data and business logic of the application.
- Manages the data, business rules, and logic for the application.
- Should be independent of the user interface.

### View:
- Represents the user interface (UI) of the application.
- Displays information to the user and captures user interactions.
- Doesn't contain any application logic but is responsible for updating the UI based on changes in the ViewModel.

### ViewModel:
- Acts as an intermediary between the Model and the View.
- Exposes data and commands to be displayed in the View.
- Contains the application logic, transforms data for the View, and handles user input.
- Keeps the View and Model separate, ensuring a clean separation of concerns.

## MVVM in SwiftUI: How it is Used

In SwiftUI, MVVM is a commonly adopted pattern due to its compatibility with the framework's declarative and reactive nature.

### Model (Data):
- SwiftUI Views are often bound to a ViewModel, which is responsible for managing the data.
- Data can come from various sources such as databases, APIs, or other services.

### View (User Interface):
- SwiftUI Views are responsible for presenting the UI to the user.
- Views declare their structure and appearance based on the data provided by the ViewModel.
- The View observes changes in the ViewModel and automatically updates when the data changes.

### ViewModel (Intermediary):
- The ViewModel exposes properties that represent the state of the UI.
- Contains logic to transform and manipulate data for the View.
- Listens for user interactions and updates the Model accordingly.

# Eristic Main Views design Overview:

## ContentView.swift

- **Readability and Structure:**
  - Well-organized code with clear sections and comments for readability.
  - Structured with extensions and private structs for maintainability.

- **Separation of Concerns:**
  - Extensions and environment values show a clear separation of concerns, promoting modularity.

- **SwiftUI Best Practices:**
  - Leverages SwiftUI features like @State, NavigationView, and various UI components.
  - Proper use of modifiers and styling for a visually appealing interface.

- **MVVM Pattern:**
  - Use of `@State` aligns with the MVVM pattern, separating view state from business logic.

- **Reusability:**
  - Modular structure promotes reusability and testability.

- **Root Routing:**
  - Chooses between WelcomeView on a first launch and FallaciesView afterwards, based on `LocalAccount.shouldAskForName`.

- **WelcomeView:**
  - Full screen name entry, reused as the rename screen from FallaciesView.
  - Continue stores the name, Skip for now leaves it empty and is remembered so the prompt is not repeated.

- **Responsive UI:**
  - Design ensures responsiveness on various devices.

- **Swift and SwiftUI Features:**
  - Utilizes Swift's safety features and SwiftUI's declarative syntax.

- **Preview Section:**
  - SwiftUI preview enables quick visual validation during development.

## FallaciesView.swift

- `@State private var isRenaming = false`: Presents the name entry screen.
- `@StateObject var stateModel = StateModel()`: Manages view state.

### Body

- **Greeting and High Score Display:**
  - Displays personalized greeting and user's best score using `stateModel`.
  - The greeting is a button: tapping it reopens WelcomeView to set or change the name.

- **CoverFlowMenu:**
  - Presents a visually appealing and interactive CoverFlowMenu.

- **Navigation Links:**
  - Provides NavigationLinks for Flash Cards and Critical Quiz sections.
  - Clear calls-to-action for seamless transitions.

### Navigation and UI Styling:

- **NavigationView:**
  - Wraps view for easy navigation and provides a navigation bar.

- **NavigationBar Handling:**
  - Hides navigation bar and back button for a clean interface.

### Overall Considerations:

- **User-Centric Design:**
  - Prioritizes user-centric approach with personalized content.

- **Local Account:**
  - `LocalAccount` owns the stored name and best score; there is no sign in and no credentials on the device.

## CoverFlowMenu.swift Design Analysis

- **Properties and Initialization:**
  - Defines array of `CoverFlowMenuItem` objects for fallacy representation.
  - Each item includes icon and title for visual identification.

- **Body:**
  - Utilizes `ScrollView` with horizontal scrolling for Cover Flow menu.
  - Iterates over menu items using `ForEach` and includes NavigationLink for detailed fallacy info.

- **Preview Section:**
  - Provides a preview of CoverFlowMenu using `#Preview` block.

- **Overall Considerations:**
  - Visual appeal enhanced with icons and titles.
  - Encourages user interaction and engagement.

## QuizView.swift

- **Properties and Initialization:**
  - `@StateObject var gameManagerVM`: Manages game state.

### Body:

- **ZStack Structure:**
  - Uses `ZStack` to handle different quiz states.

- **Conditional Check:**
  - Checks if quiz is completed and displays `QuizCompletedView`.

- **VStack for Quiz Components:**
  - Displays score, current quiz question, timer circle, and options grid.

- **Navigation and Styling:**
  - Sets navigation title as "Critical Quiz" with inline display mode.
  - Handles quiz start and reset on appearance and disappearance.

- **Animation and Interaction:**
  - Applies bounce effect to score icon and animates timer circle.

- **Preview Section:**
  - Provides preview for testing `QuizView` with sample `GameManagerVM`.

### Overall Considerations:

- **Engaging Visuals:**
  - Symbols, animations, and timer circle enhance visual appeal.

- **Interactive Elements:**
  - Encourages user interaction through various components.

- **Responsive Design:**
  - Adapts to different screen sizes with dynamic components.
