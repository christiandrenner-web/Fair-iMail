// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var mailStore: MailStore
    @EnvironmentObject var accountStore: AccountStore
    @State private var composeAccount: EmailAccount?
    @State private var showAccountPicker = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InboxView()
                .tabItem { Label("Posteingang", systemImage: "tray.fill") }
                .badge(mailStore.messages.filter { !$0.isRead }.count)
                .tag(0)

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
                .tag(1)
        }
        .overlay(alignment: .bottomTrailing) {
            composeButton
        }
    }

    private var composeButton: some View {
        Button {
            if accountStore.accounts.count > 1 {
                showAccountPicker = true
            } else if let account = accountStore.accounts.first {
                composeAccount = account
            }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(16)
                .background(Color.accentColor, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 80)
        // Bei mehreren Konten zuerst fragen, von welchem gesendet wird.
        .confirmationDialog(
            "Von welchem Konto senden?",
            isPresented: $showAccountPicker,
            titleVisibility: .visible
        ) {
            ForEach(accountStore.accounts) { account in
                Button(account.email) { composeAccount = account }
            }
            Button("Abbrechen", role: .cancel) { }
        }
        .sheet(item: $composeAccount) { account in
            let vm = ComposeViewModel(account: account)
            let _ = { vm.onSent = { draft in
                mailStore.saveSentMessage(draft: draft, account: account)
            }}()
            ComposeView(viewModel: vm)
        }
    }
}
