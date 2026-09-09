# Eristic (Think Critical) iOS App

YouTube url: https://youtu.be/j13dpPYPDAI

## Overview
Think Critical (Project Eristic) is an iOS application designed to address the twelve most common logical fallacies. It leverages Swift and SwiftUI, incorporating the Model–View–ViewModel (MVVM) architectural pattern to create an interactive and gamified learning experience. The app features Swipe Flow navigation, Flash Cards, and a Logical Fallacies quiz.

## Technologies Used
- Swift programming language
- SwiftUI framework
- Model–View–ViewModel (MVVM) architectural pattern

## Main Features

### Local Account
- There is no sign in. The app keeps a single account on the device to track progress in the Critical Quiz game.
- On first launch a welcome screen asks for a name, which can be skipped and changed later by tapping the greeting.
- The name and best score are stored in UserDefaults and never leave the device.

### Detailed Fallacies
- Utilizes the Cover Flow view for navigation.
- Users can explore different informal logical fallacies and tap on each one for detailed information, including definition, examples, why it is a fallacy, how to identify, how to avoid, consequences of using it, and how to counter it.

### Flash Fallacies
- Features 60 flash cards with scenarios of arguments and fallacy responses.
- Users can swipe right and left to navigate cards and use the shuffle button to restart.

### Critical Quiz
- A multiple-choice game with 58 different questions, where users read a fallacy response and identify the corresponding fallacy.
- Timed for 60 seconds.
- The game ends after 3 wrong answers, and the score is stored if it's higher than previous times.

### Design
- Designed for portrait mode only and doesn't respond to screen rotation.

## Minimum Requirements
- macOS Sonoma (14.1)
- Mac or MacBook with an M1 processor
- Xcode 15.0.1 (15A507)
- iPhone 12 with iOS 17.1.2

# Building and Running Eristic iOS App in Xcode

## Prerequisites:
- Make sure you have a Mac or MacBook with an M1 processor.
- Install Xcode 15.0.1 or a later version on your macOS Sonoma (14.1) from Apple's App Store.
- Ensure your iPhone is an iPhone 12 or newer and has iOS 17.1.2 installed.

## Steps:

1. **Download Eristic:**
   - Download the Eristic.zip folder from the provided source.

2. **Unzip the Folder:**
   - Locate the downloaded Eristic.zip file and unzip it.

3. **Open Xcode Project:**
   - Inside the unzipped folder, find and double-click on the file named `Eristic.xcodeproj`. This will open the project in Xcode.

4. **Xcode Interface:**
   - Once Xcode is open, you'll see the project's files and folders on the left side (Navigator column). Click on 'Project' (cmd + 1) to see the project structure.

5. **Select Build Target:**
   - In the top bar of Xcode, you should see 'Eristic > <Device>' which represents the app and the build target. Choose your build target:
     - For testing in Xcode Simulator (Not recommended): Select 'Eristic > iPhone 15 Pro Max'.
     - For testing on an actual device (iPhone 12 or newer): Connect your iPhone to your Mac.

6. **Build and Run in Xcode Simulator (Optional):**
   - If you're testing in Xcode Simulator:
     - Hit the run button (Play button) in the top left corner or press cmd + R.
     - A virtual device will be built on your Mac, representing an iPhone. Note that Xcode Simulator is not ideal for real use, but it's useful for design and testing purposes.

7. **Build and Run on an Actual Device:**
   - If you're testing on your iPhone:
     - Connect your iPhone to your Mac.
     - Trust the host Mac on your iPhone when prompted.
     - From the top bar in Xcode, select your iPhone from the drop-down menu.
     - Hit the run button (Play button) in the top left corner or press cmd + R.
     - If prompted, trust the developer on your iPhone (Settings/General/VPN & Device Management).

8. **Enjoy Eristic:**
   - The app will launch on your selected device, and you can interact with its features.

These steps should guide someone unfamiliar with Xcode through the process of building and running the Eristic iOS app. If there are any issues or questions, feel free to ask for further assistance.
