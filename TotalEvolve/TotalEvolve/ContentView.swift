//
//  ContentView.swift
//  TotalEvolve
//
//  Created by Lukas on 20/06/2023.
//

import SwiftUI
import HealthKit

import SwiftUI
import UIKit
import HealthKit

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    @Published var weight: Double?
    @Published var protein: Double?
    @Published var calories: Double?
    @Published var water: Double?
    
    private let goalWeightKey = "GoalWeight"
    private let goalProteinKey = "GoalProtein"
    private let goalCaloriesKey = "GoalCalories"
    private let goalWaterKey = "GoalWater"


    func refreshData() {
        loadData()
    }

    
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            if let error = error {
                print("Error requesting HealthKit authorization: \(error.localizedDescription)")
            } else if success {
                self.loadData()
            }
        }
    }
    
    
    func loadData() {
        loadWeight()
        loadProtein()
        loadCalories()
        loadWater()
       // loadGoals()
    }

    
    func loadWeight() {
        guard let weightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            print("Weight type is no longer available in HealthKit.")
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            if let error = error {
                print("Error retrieving weight: \(error.localizedDescription)")
                return
            }
            
            if let weightSample = samples?.first as? HKQuantitySample {
                let weightInKilograms = weightSample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                DispatchQueue.main.async {
                    self.weight = weightInKilograms
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func loadProtein() {
        guard let proteinType = HKSampleType.quantityType(forIdentifier: .dietaryProtein) else {
            print("Protein type is no longer available in HealthKit.")
            return
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: proteinType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, result, error) in
            if let error = error {
                print("Error retrieving protein data: \(error.localizedDescription)")
                return
            }
            
            if let sum = result?.sumQuantity() {
                let proteinValue = sum.doubleValue(for: HKUnit.gram())
                DispatchQueue.main.async {
                    self.protein = proteinValue
                }
            }
        }
        
        healthStore.execute(query)
    }

    func loadCalories() {
        guard let calorieType = HKSampleType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            print("Calorie type is no longer available in HealthKit.")
            return
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, result, error) in
            if let error = error {
                print("Error retrieving calorie data: \(error.localizedDescription)")
                return
            }
            
            if let sum = result?.sumQuantity() {
                let calorieValue = sum.doubleValue(for: HKUnit.kilocalorie())
                DispatchQueue.main.async {
                    self.calories = calorieValue
                }
            }
        }
        
        healthStore.execute(query)
    }

    func loadWater() {
        guard let waterType = HKSampleType.quantityType(forIdentifier: .dietaryWater) else {
            print("Water type is no longer available in HealthKit.")
            return
        }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, result, error) in
            if let error = error {
                print("Error retrieving water data: \(error.localizedDescription)")
                return
            }
            
            if let sum = result?.sumQuantity() {
                let waterValue = sum.doubleValue(for: HKUnit.literUnit(with: .milli))
                DispatchQueue.main.async {
                    self.water = waterValue
                }
            }
        }
        
        healthStore.execute(query)
    }

    

}


struct LeaderboardView: View {
    var body: some View {
        Text("This is the first view")
            .font(.largeTitle)
    }
}

struct DashboardView: View {
    @ObservedObject var healthKitManager = HealthKitManager()

    var body: some View {
        VStack {
            if healthKitManager.weight != nil {
                Text("Weight: \(healthKitManager.weight!) kg")
                Text("Protein: \(healthKitManager.protein!) g")
                Text("Calories: \(healthKitManager.calories!) kcal")
                Text("Water: \(healthKitManager.water!) L")
            } else {
                Text("Loading HealthKit data...")
            }
        }
        .onAppear {
            healthKitManager.requestAuthorization()
            healthKitManager.refreshData()
        }
    }
}



struct GymPlanView: View {
    @State private var muscles: [String] = UserDefaults.standard.stringArray(forKey: "muscles") ?? ["Rest Day", "Rest Day", "Rest Day", "Rest Day", "Rest Day", "Rest Day", "Rest Day"]
    let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    let workouts = ["Rest Day", "Back & Biceps", "Shoulders & Triceps", "Legs & Core", "Full Body"]

    @State private var showingActionSheet = false
    @State private var activeDayIndex = 0
    
    var currentDay: String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(0..<days.count, id: \.self) { i in
                    Section(header: Text(days[i]).foregroundColor(days[i] == currentDay ? .red : .black)) {
                        HStack {
                            Text(muscles[i])
                            Spacer()
                            Button(action: {
                                self.activeDayIndex = i
                                self.showingActionSheet = true
                            }) {
                                Text("Edit")
                            }
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationTitle("Gym Plan")
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(title: Text("Select workout"), message: nil, buttons: workoutButtons())
            }
        }
    }

    func workoutButtons() -> [ActionSheet.Button] {
        var buttons = workouts.map { workout in
            ActionSheet.Button.default(Text(workout)) {
                self.updateMuscle(activeDayIndex, workout: workout)
            }
        }
        buttons.append(.cancel())
        return buttons
    }

    func updateMuscle(_ dayIndex: Int, workout: String) {
        var newMuscles = self.muscles
        newMuscles[dayIndex] = workout
        self.muscles = newMuscles
        UserDefaults.standard.set(newMuscles, forKey: "muscles")
    }
}







    struct WorkoutEditView: View {
        let day: String
        @Binding var selectedWorkout: String
        let workouts = ["Rest Day", "Back & Biceps", "Shoulders & Triceps", "Legs & Core", "Full Body"]

        var body: some View {
            Form {
                Picker("Workout", selection: $selectedWorkout) {
                    ForEach(workouts, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .navigationBarTitle(Text("Workout for \(day)"))
            }
            .onDisappear {
                UserDefaults.standard.set(self.selectedWorkout, forKey: "muscles\(self.day)")
            }
        }
}

struct ContentView: View {
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            LeaderboardView()
                .tabItem {
                    Image(systemName: "1.square.fill")
                    Text("Leaderboard")
                }
                .tag(0)
            DashboardView()
                .tabItem {
                    Image(systemName: "2.square.fill")
                    Text("Dashboard")
                }
                .tag(1)
            GymPlanView()
                .tabItem {
                    Image(systemName: "3.square.fill")
                    Text("Gym Plan")
                }
                .tag(2)
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
