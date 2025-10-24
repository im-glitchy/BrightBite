//
//  MainTabView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/3/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var tabNavigation = TabNavigationManager()

    var body: some View {
        TabView(selection: $tabNavigation.selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: tabNavigation.selectedTab == 0 ? "house.fill" : "house")
                        .environment(\.symbolVariants, tabNavigation.selectedTab == 0 ? .fill : .none)
                    Text("Home")
                }
                .tag(0)

            LazyTabContent(selectedTab: tabNavigation.selectedTab, tag: 1) {
                ChatView()
            }
            .tabItem {
                Image(systemName: tabNavigation.selectedTab == 1 ? "bubble.left.fill" : "bubble.left")
                    .environment(\.symbolVariants, tabNavigation.selectedTab == 1 ? .fill : .none)
                Text("Chat")
            }
            .tag(1)

            PainMapView()
                .tabItem {
                    Image(systemName: tabNavigation.selectedTab == 2 ? "face.smiling.fill" : "face.smiling")
                        .environment(\.symbolVariants, tabNavigation.selectedTab == 2 ? .fill : .none)
                    Text("Map")
                }
                .tag(2)

            LazyTabContent(selectedTab: tabNavigation.selectedTab, tag: 3) {
                PlanView()
            }
            .tabItem {
                Image(systemName: tabNavigation.selectedTab == 3 ? "person.crop.circle.fill" : "person.crop.circle")
                    .environment(\.symbolVariants, tabNavigation.selectedTab == 3 ? .fill : .none)
                Text("Plan")
            }
            .tag(3)
        }
        .environmentObject(tabNavigation)
        .tint(.blue)
        .background(.ultraThinMaterial)
    }
}

struct LazyTabContent<Content: View>: View {
    let selectedTab: Int
    let tag: Int
    let content: () -> Content

    var body: some View {
        if selectedTab == tag {
            content()
        } else {
            Color.clear
        }
    }
}

#Preview {
    MainTabView()
}
