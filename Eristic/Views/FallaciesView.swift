//
//  FallaciesView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import SwiftUI

// MARK: - FallaciesView
struct FallaciesView: View {
    // MARK: Properties
    @State private var isLoggedOut = false
    @StateObject var stateModel = StateModel()

    // MARK: Body
    var body: some View {
        NavigationView {
            VStack {
                // Greeting and High Score Display
                VStack {
                    HStack {
                        ReusableText(text: "hello \(stateModel.currentUserName), your best score is \(stateModel.currentUserHighScore) 🏆", font: .title3, color: .gray)
                    }
                    .padding()
                }
                
                // CoverFlowMenu
                CoverFlowMenu()
                
                // Navigation Links for Flash Cards and Critical Quiz
                VStack {
                    HStack{
                        NavigationLink(destination: CardsStackView(cards: [])) {
                            Text("Flash Fallacies")
                                .font(.title3)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                                .foregroundColor(Color.white)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                        
                        NavigationLink(destination: QuizView(gameManagerVM: GameManagerVM(stateModel: stateModel))) {
                            Text("Critical Quiz")
                                .font(.title3)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                                .foregroundColor(Color.white)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
                    }
                    
                    NavigationLink(destination: FallacyFinderView()) {
                        Text("Fallacy Finder")
                            .font(.title3)
                            .frame(maxWidth: .infinity, maxHeight: 40)
                            .foregroundColor(Color.white)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                }
                .padding()
                
                // Logout Button
                Button(action :{
                    AuthenticationManager.shared.logoutUser()
                    isLoggedOut = true
                }, label:{
                    Text("Log out")
                        .font(.title3)
                        .padding()
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                        .padding()
                })
                
                // NavigationLink to ContentView when logged out
                NavigationLink(destination: ContentView(), isActive: $isLoggedOut) { EmptyView() }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FallaciesView()
    }
}
