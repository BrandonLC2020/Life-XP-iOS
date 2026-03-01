//
//  ContentView.swift
//  Life-XP-iOS
//
//  Created by Brandon Lamer-Connolly on 1/10/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        TabView {
            DashboardView(viewModel: userViewModel, healthKitManager: healthKitManager)
                .tabItem {
                    Label("Dashboard", systemImage: "person.circle.fill")
                }
            
            HabitListView(viewModel: userViewModel)
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle.fill")
                }
            
            SettingsView(viewModel: userViewModel, healthKitManager: healthKitManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            healthKitManager.requestAuthorization { success, error in
                if success {
                    healthKitManager.fetchTodaySteps()
                }
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cloud Sync")) {
                    HStack {
                        Text("Cloud Status")
                        Spacer()
                        if viewModel.isSyncing {
                            ProgressView()
                        } else {
                            Text(viewModel.lastCloudSync != nil ? "Synced" : "Not Synced")
                                .foregroundColor(viewModel.lastCloudSync != nil ? .green : .secondary)
                        }
                    }
                    
                    if let lastSync = viewModel.lastCloudSync {
                        Text("Last Cloud Sync: \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Sync with CloudKit") {
                        viewModel.fetchFromCloud()
                        viewModel.uploadToCloud()
                    }
                }

                Section(header: Text("HealthKit Permissions")) {
                    HStack {
                        Text("Authorization Status")
                        Spacer()
                        Text(healthKitManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
                    }
                    
                    Button("Request Permissions") {
                        healthKitManager.requestAuthorization { _, _ in }
                    }
                    .disabled(healthKitManager.isAuthorized)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
