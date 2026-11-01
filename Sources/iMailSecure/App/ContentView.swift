// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var accountStore: AccountStore
    @State private var showAccountSetup = false

    var body: some View {
        Group {
            if accountStore.accounts.isEmpty {
                WelcomeView(showAccountSetup: $showAccountSetup)
            } else {
                MainTabView()
            }
        }
        .sheet(isPresented: $showAccountSetup) {
            AccountSetupView()
        }
    }
}
