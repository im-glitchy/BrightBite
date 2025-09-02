//
//  MainTabView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                        .environment(\.symbolVariants, selectedTab == 0 ? .fill : .none)
                    Text("Home")
                }
                .tag(0)
            
            ChatView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "bubble.left.fill" : "bubble.left")
                        .environment(\.symbolVariants, selectedTab == 1 ? .fill : .none)
                    Text("Chat")
                }
                .tag(1)
            
            PainMapView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "face.smiling.fill" : "face.smiling")
                        .environment(\.symbolVariants, selectedTab == 2 ? .fill : .none)
                    Text("Map")
                }
                .tag(2)
            
            PlanView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.crop.circle.fill" : "person.crop.circle")
                        .environment(\.symbolVariants, selectedTab == 3 ? .fill : .none)
                    Text("Plan")
                }
                .tag(3)
        }
        .tint(.blue)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    MainTabView()
}