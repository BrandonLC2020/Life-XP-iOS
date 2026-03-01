import SwiftUI

struct HabitListView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var showingAddHabit = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Your Daily Habits")) {
                    ForEach(viewModel.habits) { habit in
                        HabitRowView(habit: habit) {
                            viewModel.completeHabit(habit)
                        }
                    }
                    .onDelete(perform: viewModel.deleteHabit)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddHabit.toggle()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
            }
        }
    }
}

struct HabitRowView: View {
    let habit: Habit
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.headline)
                    .strikethrough(habit.isCompletedToday, color: .secondary)
                Text(habit.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 10))
                    Text("\(habit.xpReward) XP")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button(action: onComplete) {
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(habit.isCompletedToday ? .green : .blue)
                    .font(.title2)
            }
            .disabled(habit.isCompletedToday)
        }
        .padding(.vertical, 4)
    }
}
