import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Character Header
                HStack(alignment: .center, spacing: 15) {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("👤")
                                .font(.system(size: 40))
                        )
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.user.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Level \(viewModel.user.level)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // XP Bar
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: viewModel.user.xpProgress)
                                .tint(.blue)
                            
                            Text("\(viewModel.user.experience) / \(viewModel.user.xpToNextLevel) XP")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 2))
                .padding(.horizontal)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatCard(title: "Strength", value: viewModel.user.strength, icon: "figure.walk", color: .red)
                    StatCard(title: "Intelligence", value: viewModel.user.intelligence, icon: "brain", color: .purple)
                    StatCard(title: "Vitality", value: viewModel.user.vitality, icon: "heart.fill", color: .green)
                    StatCard(title: "Charisma", value: viewModel.user.charisma, icon: "star.fill", color: .yellow)
                }
                .padding(.horizontal)
                
                // Health Data
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today's Health Data")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            healthKitManager.fetchTodayHealthData()
                            viewModel.syncHealthData(
                                steps: healthKitManager.stepCount, 
                                calories: healthKitManager.activeEnergy,
                                sleep: healthKitManager.sleepHours,
                                water: healthKitManager.waterIntake
                            )
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            HealthStatCard(title: "Steps", value: "\(healthKitManager.stepCount)", icon: "shoeprints.fill")
                            HealthStatCard(title: "Active Burn", value: String(format: "%.0f kcal", healthKitManager.activeEnergy), icon: "flame.fill")
                        }
                        HStack(spacing: 15) {
                            HealthStatCard(title: "Sleep", value: String(format: "%.1f hrs", healthKitManager.sleepHours), icon: "bed.double.fill")
                            HealthStatCard(title: "Water", value: String(format: "%.2f L", healthKitManager.waterIntake), icon: "drop.fill")
                        }
                    }
                    .padding(.horizontal)
                    
                    if let lastSync = viewModel.user.lastSyncDate {
                        Text("Last Synced: \(lastSync, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            healthKitManager.fetchTodayHealthData()
            // Auto-sync if data is available
            viewModel.syncHealthData(
                steps: healthKitManager.stepCount, 
                calories: healthKitManager.activeEnergy,
                sleep: healthKitManager.sleepHours,
                water: healthKitManager.waterIntake
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}

struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
            }
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }
}
